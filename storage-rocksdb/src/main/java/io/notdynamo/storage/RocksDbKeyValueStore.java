package io.notdynamo.storage;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Objects;
import org.rocksdb.Options;
import org.rocksdb.RocksDB;
import org.rocksdb.RocksDBException;
import org.rocksdb.WriteOptions;

public final class RocksDbKeyValueStore implements KeyValueStore {
    static {
        RocksDB.loadLibrary();
    }

    private static final byte TOMBSTONE_FALSE = 0;
    private static final byte TOMBSTONE_TRUE = 1;
    private static final int HEADER_BYTES = Long.BYTES + Byte.BYTES + Integer.BYTES;

    private final RocksDB db;
    private final Options options;
    private final WriteOptions syncWriteOptions;

    private RocksDbKeyValueStore(RocksDB db, Options options, WriteOptions syncWriteOptions) {
        this.db = db;
        this.options = options;
        this.syncWriteOptions = syncWriteOptions;
    }

    public static RocksDbKeyValueStore open(Path dataDir) {
        Objects.requireNonNull(dataDir, "dataDir must not be null");

        try {
            Files.createDirectories(dataDir);
        } catch (IOException e) {
            throw new StorageException("failed to create data directory: " + dataDir, e);
        }

        Options options = new Options()
            .setCreateIfMissing(true)
            .setParanoidChecks(true)
            .setUseFsync(true);
        WriteOptions writeOptions = new WriteOptions().setSync(true);

        try {
            RocksDB db = RocksDB.open(options, dataDir.toAbsolutePath().toString());
            return new RocksDbKeyValueStore(db, options, writeOptions);
        } catch (RocksDBException e) {
            writeOptions.close();
            options.close();
            throw new StorageException("failed to open RocksDB at " + dataDir, e);
        }
    }

    @Override
    public synchronized GetResult get(byte[] key) {
        validateKey(key);

        try {
            StoredRecord record = readRecord(key);
            if (record == null || record.tombstone()) {
                long version = record == null ? 0 : record.version();
                return new GetResult(false, new byte[0], version);
            }
            return new GetResult(true, record.value(), record.version());
        } catch (RocksDBException e) {
            throw new StorageException("failed to read key", e);
        }
    }

    @Override
    public synchronized long put(byte[] key, byte[] value) {
        validateKey(key);
        Objects.requireNonNull(value, "value must not be null");

        try {
            StoredRecord record = readRecord(key);
            long nextVersion = nextVersion(record);
            byte[] encoded = encode(nextVersion, false, value);
            db.put(syncWriteOptions, key, encoded);
            return nextVersion;
        } catch (RocksDBException e) {
            throw new StorageException("failed to put key", e);
        }
    }

    @Override
    public synchronized long delete(byte[] key) {
        validateKey(key);

        try {
            StoredRecord record = readRecord(key);
            long nextVersion = nextVersion(record);
            byte[] encoded = encode(nextVersion, true, new byte[0]);
            db.put(syncWriteOptions, key, encoded);
            return nextVersion;
        } catch (RocksDBException e) {
            throw new StorageException("failed to delete key", e);
        }
    }

    @Override
    public synchronized void close() {
        db.close();
        syncWriteOptions.close();
        options.close();
    }

    private StoredRecord readRecord(byte[] key) throws RocksDBException {
        byte[] encoded = db.get(key);
        if (encoded == null) {
            return null;
        }
        return decode(encoded);
    }

    private static void validateKey(byte[] key) {
        Objects.requireNonNull(key, "key must not be null");
        if (key.length == 0) {
            throw new IllegalArgumentException("key must not be empty");
        }
    }

    private static long nextVersion(StoredRecord record) {
        if (record == null) {
            return 1L;
        }
        return record.version() + 1;
    }

    private static byte[] encode(long version, boolean tombstone, byte[] value) {
        int valueLength = tombstone ? 0 : value.length;
        ByteBuffer buffer = ByteBuffer.allocate(HEADER_BYTES + valueLength).order(ByteOrder.BIG_ENDIAN);
        buffer.putLong(version);
        buffer.put(tombstone ? TOMBSTONE_TRUE : TOMBSTONE_FALSE);
        buffer.putInt(valueLength);
        if (!tombstone) {
            buffer.put(value);
        }
        return buffer.array();
    }

    private static StoredRecord decode(byte[] bytes) {
        if (bytes.length < HEADER_BYTES) {
            throw new IllegalStateException("corrupt record: header too small");
        }

        ByteBuffer buffer = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN);
        long version = buffer.getLong();
        boolean tombstone = buffer.get() == TOMBSTONE_TRUE;
        int valueLength = buffer.getInt();

        if (valueLength < 0 || buffer.remaining() != valueLength) {
            throw new IllegalStateException("corrupt record: invalid value length");
        }

        byte[] value = new byte[valueLength];
        buffer.get(value);
        return new StoredRecord(version, tombstone, value);
    }

    private record StoredRecord(long version, boolean tombstone, byte[] value) {
        private StoredRecord {
            value = Arrays.copyOf(value, value.length);
        }
    }
}
