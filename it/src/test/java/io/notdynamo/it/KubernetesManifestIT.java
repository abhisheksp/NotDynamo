package io.notdynamo.it;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

class KubernetesManifestIT {
    @Test
    void deploymentManifestsArePresentAndParseable() throws IOException {
        Path repoRoot = findRepoRoot();
        Path baseDir = repoRoot.resolve("deploy/k8s/base");
        Path overlayDir = repoRoot.resolve("deploy/k8s/overlays/dev");

        assertTrue(Files.exists(baseDir.resolve("statefulset-data.yaml")));
        assertTrue(Files.exists(baseDir.resolve("service-data-headless.yaml")));
        assertTrue(Files.exists(baseDir.resolve("deployment-control-plane.yaml")));
        assertTrue(Files.exists(baseDir.resolve("role.yaml")));
        assertTrue(Files.exists(overlayDir.resolve("kustomization.yaml")));

        List<Path> yamlFiles = new ArrayList<>();
        yamlFiles.addAll(listYamlFiles(baseDir));
        yamlFiles.addAll(listYamlFiles(overlayDir));

        Yaml yaml = new Yaml();
        for (Path yamlFile : yamlFiles) {
            String content = Files.readString(yamlFile, StandardCharsets.UTF_8);
            int documents = 0;
            for (Object ignored : yaml.loadAll(content)) {
                documents += 1;
            }
            assertTrue(documents > 0, "expected at least one YAML document in " + yamlFile);
        }

        String statefulSet = Files.readString(baseDir.resolve("statefulset-data.yaml"), StandardCharsets.UTF_8);
        assertTrue(statefulSet.contains("topologySpreadConstraints"));

        String headlessService = Files.readString(baseDir.resolve("service-data-headless.yaml"), StandardCharsets.UTF_8);
        assertTrue(headlessService.contains("clusterIP: None"));

        String leaseRole = Files.readString(baseDir.resolve("role.yaml"), StandardCharsets.UTF_8);
        assertTrue(leaseRole.contains("leases"));
    }

    @Test
    void drillScriptSupportsDryRunMode() throws IOException, InterruptedException {
        Path repoRoot = findRepoRoot();
        Path script = repoRoot.resolve("scripts/k8s/drill-node-drain.sh");
        assertTrue(Files.exists(script));

        Process process = new ProcessBuilder(
            script.toString(),
            "--dry-run",
            "--node",
            "dummy-node",
            "--namespace",
            "notdynamo"
        )
            .redirectErrorStream(true)
            .start();

        String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        int exitCode = process.waitFor();

        assertEquals(0, exitCode);
        assertTrue(output.contains("DRY_RUN:"));
        assertFalse(output.isBlank());
    }

    private static Path findRepoRoot() {
        Path current = Path.of(System.getProperty("user.dir")).toAbsolutePath();
        while (current != null) {
            if (Files.exists(current.resolve("settings.gradle.kts"))) {
                return current;
            }
            current = current.getParent();
        }
        throw new IllegalStateException("unable to locate repository root");
    }

    private static List<Path> listYamlFiles(Path directory) throws IOException {
        try (var stream = Files.walk(directory)) {
            return stream
                .filter(Files::isRegularFile)
                .filter(path -> path.getFileName().toString().endsWith(".yaml"))
                .sorted(Comparator.comparing(Path::toString))
                .toList();
        }
    }

}
