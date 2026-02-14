package io.notdynamo.it;

import io.notdynamo.storage.RocksDbKeyValueStore;
import java.nio.file.Path;
import java.util.Base64;

public final class CrashWriteProcess {
    private CrashWriteProcess() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException("usage: CrashWriteProcess <dbPath> <base64-key> <base64-value>");
        }

        Path dbPath = Path.of(args[0]);
        byte[] key = Base64.getDecoder().decode(args[1]);
        byte[] value = Base64.getDecoder().decode(args[2]);

        RocksDbKeyValueStore store = RocksDbKeyValueStore.open(dbPath);
        long version = store.put(key, value);

        System.out.println("ACK version=" + version);
        System.out.flush();

        Thread.sleep(Long.MAX_VALUE);
    }
}
