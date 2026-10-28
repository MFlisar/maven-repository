import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.*;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.apache.maven.artifact.versioning.ComparableVersion;
import org.w3c.dom.*;

class RebuildMetadata {
    record Artifact(Path directory, String group, String name, List<String> versions, String updated) {}
    static final Comparator<String> VERSIONS = Comparator
        .comparing((String version) -> new ComparableVersion(version))
        .thenComparing(Comparator.naturalOrder());

    static void require(boolean condition, String message) {
        if (!condition) throw new IllegalStateException(message);
    }

    static Document parse(Path path) throws Exception {
        var factory = DocumentBuilderFactory.newInstance();
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        return factory.newDocumentBuilder().parse(path.toFile());
    }

    static void append(Document document, Element parent, String name, String value) {
        var element = document.createElement(name);
        element.setTextContent(value);
        parent.appendChild(element);
    }

    static String timestamp(Path root, Path directory) throws Exception {
        var process = new ProcessBuilder("git", "log", "-1", "--format=%ct", "--",
            ":(glob)" + root.relativize(directory).toString().replace('\\', '/') + "/*/*.pom")
            .directory(root.toFile()).redirectErrorStream(true).start();
        var output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        require(process.waitFor() == 0 && output.matches("\\d+"),
            "Cannot determine publication time from Git history: " + directory + ": " + output);
        return DateTimeFormatter.ofPattern("yyyyMMddHHmmss").withZone(ZoneOffset.UTC)
            .format(Instant.ofEpochSecond(Long.parseLong(output)));
    }

    static void write(Artifact artifact) throws Exception {
        var document = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
        var metadata = document.createElement("metadata");
        document.appendChild(metadata);
        append(document, metadata, "groupId", artifact.group());
        append(document, metadata, "artifactId", artifact.name());
        var versioning = document.createElement("versioning");
        metadata.appendChild(versioning);
        append(document, versioning, "latest", artifact.versions().getLast());
        var releases = artifact.versions().stream()
            .filter(version -> !version.toUpperCase(Locale.ROOT).endsWith("-SNAPSHOT")).toList();
        if (!releases.isEmpty()) append(document, versioning, "release", releases.getLast());
        var versions = document.createElement("versions");
        versioning.appendChild(versions);
        for (var version : artifact.versions()) append(document, versions, "version", version);
        append(document, versioning, "lastUpdated", artifact.updated());

        var output = new java.io.ByteArrayOutputStream();
        var transformer = TransformerFactory.newInstance().newTransformer();
        transformer.setOutputProperty(OutputKeys.INDENT, "yes");
        transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
        transformer.transform(new DOMSource(document), new StreamResult(output));
        var content = output.toByteArray();
        var path = artifact.directory().resolve("maven-metadata.xml");
        Files.write(path, content);
        for (var entry : Map.of("md5", "MD5", "sha1", "SHA-1", "sha256", "SHA-256", "sha512", "SHA-512").entrySet()) {
            var digest = MessageDigest.getInstance(entry.getValue()).digest(content);
            Files.writeString(Path.of(path + "." + entry.getKey()), HexFormat.of().formatHex(digest) + "\n",
                StandardCharsets.US_ASCII);
        }
    }

    static void rebuild(Path root) throws Exception {
        var artifacts = root.resolve("artifacts");
        if (!Files.exists(artifacts)) {
            System.out.println("No artifacts remain; no metadata to rebuild.");
            return;
        }
        var directories = new TreeMap<Path, Set<String>>();
        try (var files = Files.walk(artifacts)) {
            for (var pom : files.filter(path -> path.toString().endsWith(".pom")).sorted().toList()) {
                var versionDirectory = pom.getParent();
                var directory = versionDirectory.getParent();
                var version = versionDirectory.getFileName().toString();
                var name = directory.getFileName().toString();
                require(pom.getFileName().toString().startsWith(name + "-"),
                    "Unexpected Maven POM location: " + pom);
                // Parse POMs to reject corrupt publications before changing any metadata.
                require(parse(pom).getDocumentElement().getTagName().equals("project"), "Invalid POM: " + pom);
                directories.computeIfAbsent(directory, key -> new TreeSet<>(VERSIONS)).add(version);
            }
        }
        var orphaned = new ArrayList<Path>();
        try (var files = Files.walk(artifacts)) {
            for (var metadata : files.filter(path -> path.getFileName().toString().equals("maven-metadata.xml")).toList()) {
                var metadataRoot = parse(metadata).getDocumentElement();
                boolean snapshotLevel = false;
                var children = metadataRoot.getChildNodes();
                for (int i = 0; i < children.getLength(); i++) {
                    if (children.item(i).getNodeName().equals("version")) snapshotLevel = true;
                }
                if (!directories.containsKey(metadata.getParent()) && !snapshotLevel) {
                    require(!Files.exists(Path.of(metadata + ".asc")),
                        "Signed metadata cannot be removed without re-signing: " + metadata);
                    orphaned.add(metadata);
                }
            }
        }
        var plans = new ArrayList<Artifact>();
        for (var entry : directories.entrySet()) {
            var directory = entry.getKey();
            require(!Files.exists(directory.resolve("maven-metadata.xml.asc")),
                "Signed metadata cannot be rebuilt without re-signing: " + directory);
            var groupPath = artifacts.relativize(directory.getParent());
            require(groupPath.getNameCount() > 0, "Missing Maven group path: " + directory);
            var group = new ArrayList<String>();
            groupPath.forEach(part -> group.add(part.toString()));
            plans.add(new Artifact(directory, String.join(".", group), directory.getFileName().toString(),
                List.copyOf(entry.getValue()), timestamp(root, directory)));
        }
        for (var plan : plans) write(plan);
        for (var metadata : orphaned) {
            for (var suffix : List.of("", ".md5", ".sha1", ".sha256", ".sha512")) {
                Files.deleteIfExists(Path.of(metadata + suffix));
            }
        }
        System.out.println("Rebuilt metadata and checksums for " + plans.size() + " artifacts.");
    }

    static void test() throws Exception {
        var versions = new ArrayList<>(List.of("0.0.2", "0.0.1-alpha10", "0.0.1",
            "0.0.1-alpha02", "0.0.2-SNAPSHOT", "0.0.1-rc1"));
        versions.sort(VERSIONS);
        require(versions.equals(List.of("0.0.1-alpha02", "0.0.1-alpha10", "0.0.1-rc1",
            "0.0.1", "0.0.2-SNAPSHOT", "0.0.2")), "Incorrect Maven ordering");
        var directory = Files.createTempDirectory("maven-metadata-test-");
        try {
            var artifact = new Artifact(directory, "io.github.example", "core", versions, "20261028100000");
            write(artifact);
            var metadata = directory.resolve("maven-metadata.xml");
            var original = Files.readAllBytes(metadata);
            var document = parse(metadata);
            require(document.getElementsByTagName("latest").item(0).getTextContent().equals("0.0.2"), "Invalid latest");
            require(document.getElementsByTagName("version").getLength() == versions.size(), "Lost versions");
            write(artifact);
            require(Arrays.equals(original, Files.readAllBytes(metadata)), "Non-idempotent output");
            write(new Artifact(directory, artifact.group(), artifact.name(),
                List.of("0.0.1", "0.0.2-SNAPSHOT"), artifact.updated()));
            document = parse(metadata);
            require(document.getElementsByTagName("release").item(0).getTextContent().equals("0.0.1"),
                "Snapshots must not be releases");
            var expected = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(metadata)));
            require(Files.readString(Path.of(metadata + ".sha256")).trim().equals(expected), "Invalid checksum");
            var repository = directory.resolve("repository");
            var versionDirectory = repository.resolve("artifacts/io/github/example/core/0.0.1-alpha01");
            Files.createDirectories(versionDirectory);
            Files.writeString(versionDirectory.resolve("core-0.0.1-alpha01.pom"), "<project/>");
            for (var command : List.of(
                    List.of("git", "init", "--quiet"),
                    List.of("git", "add", "."),
                    List.of("git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                        "commit", "--quiet", "-m", "Fixture"))) {
                var process = new ProcessBuilder(command).directory(repository.toFile()).inheritIO().start();
                require(process.waitFor() == 0, "Failed to create Git fixture");
            }
            rebuild(repository);
            var generated = versionDirectory.getParent().resolve("maven-metadata.xml");
            document = parse(generated);
            require(document.getElementsByTagName("groupId").item(0).getTextContent().equals("io.github.example"),
                "Incorrect group path");
            require(document.getElementsByTagName("latest").item(0).getTextContent().equals("0.0.1-alpha01"),
                "Incorrect directory version");
            original = Files.readAllBytes(generated);
            rebuild(repository);
            require(Arrays.equals(original, Files.readAllBytes(generated)), "Rebuild must be idempotent");
            var newerDirectory = versionDirectory.getParent().resolve("0.0.2");
            Files.createDirectories(newerDirectory);
            Files.writeString(newerDirectory.resolve("core-0.0.2.pom"), "<project/>");
            rebuild(repository);
            require(parse(generated).getElementsByTagName("latest").item(0).getTextContent().equals("0.0.2"),
                "New version must be included");
            Files.delete(newerDirectory.resolve("core-0.0.2.pom"));
            Files.delete(newerDirectory);
            rebuild(repository);
            require(parse(generated).getElementsByTagName("latest").item(0).getTextContent().equals("0.0.1-alpha01"),
                "Deleted version must be removed");
            Files.delete(versionDirectory.resolve("core-0.0.1-alpha01.pom"));
            Files.delete(versionDirectory);
            rebuild(repository);
            require(!Files.exists(generated) && !Files.exists(Path.of(generated + ".sha256")),
                "Last version deletion must remove orphaned metadata and checksums");
            var snapshotDirectory = versionDirectory.getParent().resolve("0.0.3-SNAPSHOT");
            Files.createDirectories(snapshotDirectory);
            var snapshotMetadata = snapshotDirectory.resolve("maven-metadata.xml");
            Files.writeString(snapshotMetadata, "<metadata><version>0.0.3-SNAPSHOT</version><versioning/></metadata>");
            rebuild(repository);
            require(Files.exists(snapshotMetadata), "Snapshot-level metadata must not be removed");
        } finally {
            try (var files = Files.walk(directory)) {
                for (var file : files.sorted(Comparator.reverseOrder()).toList()) {
                    if (Files.getFileStore(file).supportsFileAttributeView("dos")) {
                        Files.setAttribute(file, "dos:readonly", false);
                    }
                    Files.delete(file);
                }
            }
        }
        System.out.println("Metadata tests passed.");
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && args[0].equals("--test")) test();
        else rebuild(Path.of(args.length == 0 ? "." : args[0]).toAbsolutePath().normalize());
    }
}
