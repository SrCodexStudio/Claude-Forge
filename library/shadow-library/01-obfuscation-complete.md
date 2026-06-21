# Shadow Library: Code Obfuscation Complete Guide

> Reference knowledge for protecting Java/Kotlin applications with ProGuard/R8
> Read BEFORE configuring obfuscation for Minecraft plugins or JVM applications

---

## ProGuard/R8 Fundamentals

### What ProGuard Does

ProGuard operates on compiled JVM bytecode (.class files) and performs four sequential passes:

1. **Shrinking** -- Removes unreachable classes, fields, and methods. Dead code elimination at the bytecode level. Reduces JAR size significantly by stripping anything not referenced from entry points.

2. **Optimization** -- Inlines short methods, removes unused parameters, simplifies control flow, propagates constants, merges identical code paths. Can yield 5-20% runtime speedup in hot paths.

3. **Obfuscation** -- Renames classes, fields, and methods to meaningless short identifiers (`a`, `b`, `c`). Destroys semantic meaning for anyone reading decompiled output. The primary anti-reverse-engineering pass.

4. **Preverification** -- Adds stack map frames required by Java 7+ class verification. Ensures the output bytecode is valid for modern JVMs.

### R8 vs ProGuard

R8 is Google's replacement for ProGuard, built into the Android Gradle Plugin. Key differences:

| Aspect | ProGuard | R8 |
|--------|----------|----|
| Maintained by | GuardSquare | Google |
| Primary target | General JVM / Android | Android (AGP integrated) |
| Speed | Slower (separate tool) | Faster (integrated into D8) |
| Configuration | `proguard-rules.pro` | Same syntax, same files |
| Desktop JVM support | Full | Not designed for it |
| Kotlin awareness | Basic | Better inline/lambda handling |

**For Minecraft plugins and desktop JVM projects, use ProGuard directly.** R8 is only relevant if you are building Android applications or libraries.

### Name Mangling

During obfuscation, ProGuard replaces every non-kept identifier with the shortest available name from a character pool. Without a custom dictionary, it cycles through single-character names:

```
com.example.plugin.manager.EconomyManager  -->  a.b.c.d.a
getBalance(UUID)                           -->  a(UUID)
private double cachedBalance               -->  a
```

Custom dictionaries let you use misleading names instead of sequential letters. Create a text file with one name per line:

```
# dictionary.txt -- misleading names to confuse reverse engineers
hashCode
toString
valueOf
iterator
compareTo
serialize
clone
finalize
notify
```

Configure in ProGuard:

```
-obfuscationdictionary dictionary.txt
-classobfuscationdictionary dictionary.txt
-packageobfuscationdictionary dictionary.txt
```

### When Obfuscation Breaks Things

Obfuscation renames identifiers. Any mechanism that references code by string name will break:

- **Reflection** -- `Class.forName("com.example.MyClass")` fails when MyClass becomes `a`
- **Serialization** -- Java Serializable, Gson, Jackson use field names. Renaming fields breaks deserialization of existing data
- **YAML/JSON config mapping** -- Bukkit ConfigurationSerializable maps config keys to field names
- **Service loaders** -- META-INF/services files reference class names by string
- **Annotation processors** -- Some processors emit code referencing original names
- **JNI** -- Native methods are resolved by exact mangled names
- **plugin.yml / paper-plugin.yml** -- Declares main class by fully qualified name

The solution is always the same: add `-keep` rules for anything referenced by name at runtime.

---

## Keep Rules for Minecraft Plugins

### Why Bukkit API Classes Must Be Kept

The Bukkit/Paper server loads your plugin via reflection. It reads `plugin.yml`, finds the `main` class string, calls `Class.forName()`, and invokes lifecycle methods by name. If ProGuard renames your main class, the server cannot find it.

Similarly, `@EventHandler` methods are discovered via reflection scanning. Command executors are registered by interface. Config serialization uses field names. All of these break under obfuscation without keep rules.

### Complete proguard-rules.pro for Minecraft Plugins

```proguard
# ========================================================
# ProGuard Rules -- Minecraft (Paper/Spigot) Kotlin Plugin
# ========================================================

# --- KOTLIN RUNTIME ---
# Keep Kotlin metadata so inline functions and coroutines work
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations
-keepattributes AnnotationDefault
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# Keep Kotlin metadata annotation itself
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }

# Kotlin coroutines internals that use reflection
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-keepclassmembernames class kotlinx.coroutines.internal.MainDispatcherLoader {
    *;
}

# --- MAIN PLUGIN CLASS ---
# Must match the class declared in plugin.yml / paper-plugin.yml
-keep public class com.example.myplugin.MyPlugin extends org.bukkit.plugin.java.JavaPlugin {
    public <init>();
    public void onEnable();
    public void onDisable();
    public void onLoad();
}

# --- EVENT HANDLERS ---
# Any method annotated with @EventHandler is called via reflection
-keepclassmembers class * {
    @org.bukkit.event.EventHandler <methods>;
}

# Keep all Listener implementations (server registers them by interface)
-keep class * implements org.bukkit.event.Listener {
    <methods>;
}

# --- COMMANDS ---
# CommandExecutor and TabCompleter interfaces resolved at runtime
-keep class * implements org.bukkit.command.CommandExecutor {
    public boolean onCommand(...);
}
-keep class * implements org.bukkit.command.TabCompleter {
    public java.util.List onTabComplete(...);
}

# --- CONFIGURATION SERIALIZABLE ---
# Bukkit deserializes these classes from YAML config by name
-keep class * implements org.bukkit.configuration.serialization.ConfigurationSerializable {
    public static <methods>;
    <fields>;
}

# --- PAPER 1.21+ COMPATIBILITY ---
# Paper uses Mojang-mapped internals; keep bridge methods
# Paper's plugin loader uses ServiceLoader patterns in newer versions
-keepattributes Module*
-keep class io.papermc.paper.plugin.** { *; }

# Paper 1.21+ bootstrap and loader classes
-keep class * implements io.papermc.paper.plugin.bootstrap.PluginBootstrap {
    public <init>();
    public void bootstrap(io.papermc.paper.plugin.bootstrap.BootstrapContext);
}
-keep class * implements io.papermc.paper.plugin.loader.PluginLoader {
    public <init>();
    public void classloader(io.papermc.paper.plugin.loader.PluginClasspathBuilder);
}

# --- ENUM CLASSES ---
# Enums use valueOf() which relies on field names
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- SCHEDULED TASKS ---
# BukkitRunnable subclasses are instantiated and run by reflection
-keep class * extends org.bukkit.scheduler.BukkitRunnable {
    public void run();
}

# --- GENERAL SAFETY ---
# Keep native method names (JNI resolution)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Suppress warnings for server-provided libraries
-dontwarn org.bukkit.**
-dontwarn net.kyori.**
-dontwarn io.papermc.**
-dontwarn com.mojang.**
-dontwarn net.minecraft.**
-dontwarn org.spigotmc.**

# Do not optimize away stack traces needed for debugging
-renamesourcefileattribute SourceFile
```

### Paper 1.21+ Specific Notes

Paper 1.21 introduced a new plugin loading system (`paper-plugin.yml` alongside `plugin.yml`). If your plugin uses the new paper-plugin.yml format:

- The `bootstrapper` and `loader` classes MUST be kept with their no-arg constructors
- `has-open-classloader: true` in paper-plugin.yml affects class visibility
- Paper's dependency injection for lifecycle uses reflection on constructor parameters
- Stricter class loading can trigger `IllegalArgumentException: Duplicate key` when obfuscated Kotlin metadata conflicts with Paper's internal reflection. The rules above for `kotlin.reflect.**` prevent this. If the error persists, broaden to `-keep class kotlin.** { *; }`

---

## Keep Rules Syntax Reference

### Core Rule Types

```proguard
# -keep: Preserve the class AND its specified members from shrinking AND obfuscation
-keep class com.example.MyClass { *; }

# -keepclassmembers: Keep members IF the class itself survives shrinking
# The class name CAN be obfuscated; only member names are preserved
-keepclassmembers class com.example.MyClass {
    public void importantMethod();
}

# -keepclasseswithmembers: Keep the class AND members, but ONLY if ALL
# specified members exist. Useful for conditional keeps.
-keepclasseswithmembers class * {
    public static void main(java.lang.String[]);
}

# -keepnames: Allow shrinking (removal) but prevent obfuscation if kept
-keepnames class com.example.MyClass

# -keepclassmembernames: Same as keepnames but for members only
-keepclassmembernames class * implements java.io.Serializable {
    <fields>;
}
```

### Wildcards

```proguard
# Single * -- matches any part of a name, excluding package separators
-keep class com.example.* { *; }
# Matches: com.example.Foo, com.example.Bar
# Does NOT match: com.example.sub.Baz

# Double ** -- matches any part of a name, INCLUDING package separators
-keep class com.example.** { *; }
# Matches: com.example.Foo, com.example.sub.Baz, com.example.a.b.c.Deep

# Triple *** -- matches any type (used in method signatures)
-keep class * {
    public *** getStuff(...);
}
# Matches any return type, any method named getStuff with any parameters
```

### Field and Method Specifications

```proguard
# All fields
-keepclassmembers class * { <fields>; }

# All methods
-keepclassmembers class * { <methods>; }

# All constructors
-keepclassmembers class * { <init>(...); }

# Specific method signature
-keepclassmembers class * {
    public void onEnable();
    public boolean onCommand(org.bukkit.command.CommandSender,
                             org.bukkit.command.Command,
                             java.lang.String,
                             java.lang.String[]);
}

# Methods by return type
-keepclassmembers class * {
    public java.util.Map serialize();
}
```

### Annotation-Based Rules

```proguard
# Keep any class annotated with a specific annotation
-keep @com.example.KeepThisClass class * { *; }

# Keep methods with a specific annotation
-keepclassmembers class * {
    @org.bukkit.event.EventHandler <methods>;
}

# Keep fields annotated for serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
```

### -keepattributes Reference

```proguard
-keepattributes Signature                    # Generic type info (needed for Kotlin reified)
-keepattributes *Annotation*                 # All annotations
-keepattributes InnerClasses                 # Inner class references
-keepattributes EnclosingMethod              # Enclosing method refs
-keepattributes Exceptions                   # Throws declarations
-keepattributes SourceFile,LineNumberTable   # Stack trace readability
```

### Conditional Rules (-if ... -keep)

```proguard
# If a class implements Listener, keep its @EventHandler methods
-if class * implements org.bukkit.event.Listener
-keepclassmembers class <1> {
    @org.bukkit.event.EventHandler <methods>;
}

# If a class has a serialize() method, keep the deserialize() companion
-if class * {
    public java.util.Map serialize();
}
-keep class <1> {
    public static <1> deserialize(java.util.Map);
    public static <1> valueOf(java.util.Map);
}
```

The `<1>` backreference refers to the first wildcard match from the `-if` condition.

---

## String Encryption Patterns

### Why It Matters

Decompilers like CFR, Procyon, and JD-GUI reconstruct source code from bytecode. Strings are stored verbatim in the constant pool. Anyone opening your JAR sees:

```kotlin
// Visible in decompiled output without string encryption:
val licenseUrl = "https://api.myserver.com/v2/license/validate"
val dbPassword = "super_secret_password_123"
val webhookUrl = "https://discord.com/api/webhooks/123456/abcdef"
```

String encryption transforms these literals at build time so the bytecode contains ciphertext. A runtime decryption stub restores the original value.

### XOR Obfuscation (Lightweight)

Fast, tiny overhead, sufficient to defeat casual string searches:

```kotlin
object StringShield {

    // Key is split across multiple constants to resist pattern matching
    private const val K0: Int = 0x4A
    private const val K1: Int = 0x7F
    private const val K2: Int = 0x33
    private const val K3: Int = 0x1C

    private val keyRing = intArrayOf(K0, K1, K2, K3)

    /**
     * Encrypts a plaintext string into a hex-encoded ciphertext.
     * Call this at BUILD TIME to produce the encrypted literals.
     */
    fun encrypt(plaintext: String): String {
        val bytes = plaintext.toByteArray(Charsets.UTF_8)
        val encrypted = ByteArray(bytes.size)
        for (i in bytes.indices) {
            encrypted[i] = (bytes[i].toInt() xor keyRing[i % keyRing.size]).toByte()
        }
        return encrypted.joinToString("") { "%02x".format(it) }
    }

    /**
     * Decrypts a hex-encoded ciphertext back to plaintext.
     * Called at RUNTIME inside the obfuscated JAR.
     */
    fun decrypt(cipherHex: String): String {
        val bytes = cipherHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        val decrypted = ByteArray(bytes.size)
        for (i in bytes.indices) {
            decrypted[i] = (bytes[i].toInt() xor keyRing[i % keyRing.size]).toByte()
        }
        return String(decrypted, Charsets.UTF_8)
    }
}

// Usage after build-time encryption:
// val licenseUrl = StringShield.decrypt("2a1f5640...") // was "https://api.myserver.com/..."
```

### AES Runtime Decryption (Stronger)

For higher-value secrets where XOR is insufficient:

```kotlin
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec
import javax.crypto.spec.IvParameterSpec
import java.util.Base64

object SecureVault {

    // Key and IV should be derived at runtime, not stored as literals.
    // This example splits them across multiple operations to slow static analysis.
    private fun deriveKey(): ByteArray {
        val part1 = byteArrayOf(0x31, 0x42, 0x53, 0x64, 0x75, 0x16, 0x27, 0x38)
        val part2 = byteArrayOf(0x49, 0x5A, 0x6B, 0x7C, 0x0D, 0x1E, 0x2F, 0x30)
        return part1 + part2 // 16 bytes = AES-128
    }

    private fun deriveIv(): ByteArray {
        // Derived from class metadata to resist extraction
        val seed = SecureVault::class.java.name.hashCode()
        val iv = ByteArray(16)
        for (i in iv.indices) {
            iv[i] = ((seed shr (i % 4 * 8)) and 0xFF).toByte()
        }
        return iv
    }

    fun decrypt(cipherBase64: String): String {
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        val keySpec = SecretKeySpec(deriveKey(), "AES")
        val ivSpec = IvParameterSpec(deriveIv())
        cipher.init(Cipher.DECRYPT_MODE, keySpec, ivSpec)
        val decrypted = cipher.doFinal(Base64.getDecoder().decode(cipherBase64))
        return String(decrypted, Charsets.UTF_8)
    }

    /**
     * Build-time utility. Run this to produce encrypted literals for your source code.
     */
    fun encrypt(plaintext: String): String {
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        val keySpec = SecretKeySpec(deriveKey(), "AES")
        val ivSpec = IvParameterSpec(deriveIv())
        cipher.init(Cipher.ENCRYPT_MODE, keySpec, ivSpec)
        val encrypted = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        return Base64.getEncoder().encodeToString(encrypted)
    }
}
```

### Lookup Table Approach

Store encoded strings in a shuffled array and reference by index. After obfuscation, the decompiler shows `a.a[3]` instead of `"license_key"`:

```kotlin
internal object S {
    private val pool = arrayOf(
        intArrayOf(50, 28, 28, 24, 27),  // index 0: encoded fragment
        intArrayOf(41, 35, 37, 30, 42),  // index 1: encoded fragment
        intArrayOf(18, 55, 12, 67, 91),  // index 2: encoded fragment
    )

    // Retrieve and decode by index. After obfuscation this becomes a.a(3)
    fun g(i: Int): String = String(pool[i].map { (it xor 0x5A).toChar() }.toCharArray())
}
```

### Gradle Build-Time Encryption Task

Automate string encryption as part of the build pipeline:

```kotlin
// In build.gradle.kts
tasks.register("encryptStrings") {
    group = "obfuscation"
    description = "Encrypt sensitive string literals for embedding in source"

    doLast {
        // Read plaintext secrets from a file NOT committed to git
        val secretsFile = file("secrets.properties")
        if (!secretsFile.exists()) {
            throw GradleException("secrets.properties not found. Create from secrets.properties.example")
        }

        val key = 0x5A
        val props = java.util.Properties().apply { load(secretsFile.inputStream()) }
        val output = StringBuilder("// AUTO-GENERATED -- do not edit manually\n")
        output.appendLine("object EncryptedStrings {")

        props.forEach { name, value ->
            val encoded = value.toString().map { it.code xor key }
            output.appendLine("    val $name = S.g(intArrayOf(${encoded.joinToString(", ")}))")
        }

        output.appendLine("}")
        file("src/main/kotlin/com/example/generated/EncryptedStrings.kt")
            .writeText(output.toString())

        println("Encrypted ${props.size} strings into EncryptedStrings.kt")
    }
}
```

---

## Gradle Integration

### ProGuard Plugin in build.gradle.kts

```kotlin
plugins {
    kotlin("jvm") version "1.9.22"
    id("com.github.johnrengelman.shadow") version "8.1.1"
}

// ProGuard is applied as a standalone dependency, not a plugin
buildscript {
    repositories { mavenCentral() }
    dependencies {
        classpath("com.guardsquare:proguard-gradle:7.5.0")
    }
}

repositories {
    mavenCentral()
    maven("https://repo.papermc.io/repository/maven-public/")
}

dependencies {
    // Server API -- compileOnly so it is not bundled
    compileOnly("io.papermc.paper:paper-api:1.21.4-R0.1-SNAPSHOT")

    // Runtime dependencies to bundle
    implementation(kotlin("stdlib"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("com.zaxxer:HikariCP:5.1.0")
}

// Step 1: Shadow JAR bundles all runtime dependencies into one fat JAR
tasks.shadowJar {
    archiveClassifier.set("shadow")
    relocate("kotlin", "com.example.myplugin.libs.kotlin")
    relocate("kotlinx", "com.example.myplugin.libs.kotlinx")
    relocate("com.zaxxer.hikari", "com.example.myplugin.libs.hikari")

    // Exclude unnecessary metadata
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")
    exclude("META-INF/maven/**")
}

// Step 2: ProGuard processes the shadow JAR
tasks.register<proguard.gradle.ProGuardTask>("proguardJar") {
    dependsOn(tasks.shadowJar)

    // Input: the shadow JAR
    injars(tasks.shadowJar.flatMap { it.archiveFile })

    // Output: final obfuscated JAR
    outjars(layout.buildDirectory.file("libs/${project.name}-${project.version}.jar"))

    // Library JARs -- classes provided at runtime by the server, not bundled
    val javaHome = System.getProperty("java.home")
    libraryjars("$javaHome/jmods/java.base.jmod")
    libraryjars("$javaHome/jmods/java.logging.jmod")
    libraryjars("$javaHome/jmods/java.sql.jmod")
    libraryjars("$javaHome/jmods/java.management.jmod")

    // Paper API as library (provided at runtime)
    configurations.compileClasspath.get().files
        .filter { it.name.contains("paper-api") }
        .forEach { libraryjars(it) }

    // ProGuard configuration file
    configuration("proguard-rules.pro")

    // Produce mapping file for stack trace deobfuscation
    printmapping(layout.buildDirectory.file("proguard/mapping.txt"))
}

// Wire the default build task to produce the obfuscated JAR
tasks.named("build") {
    dependsOn("proguardJar")
}
```

### injars / outjars / libraryjars Explained

- **injars** -- Your compiled code (the shadow JAR containing all bundled dependencies). ProGuard processes these classes: shrinks, optimizes, obfuscates.
- **outjars** -- Where ProGuard writes the final processed JAR.
- **libraryjars** -- Classes used at compile time but provided at runtime (server API, JDK modules). ProGuard reads these for type resolution but does NOT include them in the output. For Java 9+ modules, reference individual `.jmod` files instead of `rt.jar`.

---

## Dual Build Configuration (Dev/Prod)

### Development Build (No Obfuscation)

During development you want fast iteration with readable stack traces:

```kotlin
// buildDev task -- shadow JAR only, no ProGuard
tasks.register<Copy>("buildDev") {
    group = "build"
    description = "Build unobfuscated JAR for development testing"

    dependsOn(tasks.shadowJar)

    from(tasks.shadowJar.flatMap { it.archiveFile })
    into(layout.buildDirectory.dir("dev"))
    rename { "${project.name}-${project.version}-dev.jar" }

    doLast {
        println("Development JAR: build/dev/${project.name}-${project.version}-dev.jar")
    }
}
```

### Production Build (Full Obfuscation)

```kotlin
tasks.register("buildProd") {
    group = "build"
    description = "Build fully obfuscated JAR for production release"
    dependsOn("proguardJar")
    doLast {
        val out = layout.buildDirectory.file("libs/${project.name}-${project.version}.jar").get().asFile
        println("Production JAR: ${out.absolutePath} (${out.length() / 1024} KB)")
    }
}
```

### mapping.txt for Debugging

ProGuard writes a mapping file that records every rename:

```
com.example.myplugin.manager.EconomyManager -> a.b.c.d:
    double cachedBalance -> a
    java.util.UUID ownerUuid -> b
    double getBalance(java.util.UUID) -> a
    void setBalance(java.util.UUID,double) -> b
```

**Always archive mapping.txt with each release.** Without it, obfuscated stack traces are unreadable.

### ReTrace for Stack Traces

When a user reports a crash with obfuscated names:

```
java.lang.NullPointerException
    at a.b.c.d.a(Unknown Source)
    at a.b.e.a(Unknown Source)
```

Use ReTrace to deobfuscate:

```bash
java -jar proguard-retrace.jar mapping.txt stacktrace.txt
```

Output after retrace:

```
java.lang.NullPointerException
    at com.example.myplugin.manager.EconomyManager.getBalance(EconomyManager.kt:47)
    at com.example.myplugin.command.BalanceCommand.onCommand(BalanceCommand.kt:23)
```

### Version-Tagged Mapping Storage

```kotlin
tasks.register<Copy>("archiveMapping") {
    dependsOn("proguardJar")
    from(layout.buildDirectory.file("proguard/mapping.txt"))
    into(layout.buildDirectory.dir("mappings"))
    rename { "mapping-${project.version}.txt" }
}
```

### Switch Between Builds

```kotlin
// In build.gradle.kts -- use -Pdev flag
val isDev = project.hasProperty("dev")

tasks.register("deploy") {
    dependsOn(if (isDev) "buildDev" else "buildProd")
}
```

Run `gradle deploy -Pdev` for development, `gradle deploy` for production.

---

## Anti-Decompilation Techniques

### Control Flow Obfuscation

Replace linear execution with switch-based dispatchers. ProGuard does not do this natively, but commercial tools (Zelix KlassMaster, Allatori, DexGuard) do. The concept:

```kotlin
// Original (readable):
fun process(input: Int): String {
    val doubled = input * 2
    val result = doubled + 10
    return "Result: $result"
}

// After control flow flattening (conceptual):
fun process(input: Int): String {
    var state = 0
    var doubled = 0
    var result = 0
    while (true) {
        when (state) {
            0 -> { doubled = input * 2; state = 1 }
            1 -> { result = doubled + 10; state = 2 }
            2 -> return "Result: $result"
        }
    }
}
```

### Opaque Predicates

Insert conditions that always evaluate to the same value but are hard for static analyzers to resolve:

```kotlin
// The condition is always true at runtime, but decompilers cannot prove it statically
@Suppress("KotlinConstantConditions")
private fun opaqueTrue(): Boolean {
    val x = System.nanoTime()
    return (x * x + 1) > 0  // true for all practical long values
}
```

### String Array Shuffling

Instead of inline string constants, store fragments in shuffled arrays and reassemble at runtime:

```kotlin
private val fragments = arrayOf("li", "api", "se/", "http", "cen", "s://", "val", "idate")

private fun assembleUrl(): String {
    return buildString {
        append(fragments[3]) // "http"
        append(fragments[5]) // "s://"
        append(fragments[1]) // "api"
        // continued with remaining fragments in scrambled order
    }
}
```

### Synthetic Methods

Kotlin naturally generates synthetic bridge methods for default parameters, companion objects, coroutines, and inline classes. These confuse decompilers expecting standard Java patterns. Leveraging these Kotlin features adds obfuscation depth without explicit effort.

### Limitations -- Determined RE Always Wins

No obfuscation is unbreakable. A determined reverse engineer with a debugger, dynamic analysis tools (Java agents, bytecode instrumentation), and enough time will always recover the logic. Obfuscation raises the cost and effort required. It is a speed bump, not a wall.

**Layered defense philosophy:**

1. ProGuard shrinking + obfuscation (baseline -- always do this)
2. String encryption (prevents grep-based secret discovery)
3. Control flow obfuscation (slows manual analysis)
4. Server-side validation (moves critical logic out of the client entirely)
5. License checks with server callbacks (cannot be patched out of bytecode alone)

Each layer independently slows an attacker. Combined, they make casual piracy uneconomical.

---

## License Verification Patterns

### Server-Side HTTP Check

The only license check that cannot be trivially patched out of bytecode:

```kotlin
import java.net.HttpURLConnection
import java.net.URI
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class LicenseManager(
    private val licenseServerUrl: String, // from encrypted config, never hardcoded
    private val pluginVersion: String,
) {

    data class LicenseResult(
        val valid: Boolean,
        val message: String,
        val expiresAt: Long = 0L, // epoch millis, 0 = perpetual
    )

    /**
     * Validates the license key against the remote server.
     * Call this from onEnable() inside a coroutine on Dispatchers.IO.
     */
    suspend fun validate(licenseKey: String, serverIp: String): LicenseResult =
        withContext(Dispatchers.IO) {
            try {
                val url = URI("$licenseServerUrl/validate").toURL()
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("User-Agent", "PluginLicense/$pluginVersion")
                conn.connectTimeout = 5_000
                conn.readTimeout = 5_000
                conn.doOutput = true

                val body = """{"key":"$licenseKey","server":"$serverIp","version":"$pluginVersion"}"""
                conn.outputStream.use { it.write(body.toByteArray()) }

                val responseCode = conn.responseCode
                if (responseCode == 200) {
                    val responseBody = conn.inputStream.bufferedReader().readText()
                    // Parse JSON -- use kotlinx.serialization or Gson in production
                    LicenseResult(valid = true, message = "License verified")
                } else {
                    val errorBody = conn.errorStream?.bufferedReader()?.readText() ?: "Unknown"
                    LicenseResult(valid = false, message = "Rejected: $errorBody")
                }
            } catch (e: Exception) {
                // Grace period: allow the plugin to run if the license server is unreachable
                // but flag it for retry on next restart
                LicenseResult(valid = true, message = "Offline grace: ${e.message}")
            }
        }
}
```

### Hardware Fingerprinting

Generate a machine-specific identifier so a license key is bound to one server:

```kotlin
import java.net.NetworkInterface
import java.security.MessageDigest

object MachineFingerprint {

    fun generate(): String {
        val components = buildList {
            // MAC address of first non-loopback interface
            NetworkInterface.getNetworkInterfaces()?.toList()
                ?.firstOrNull { !it.isLoopback && it.hardwareAddress != null }
                ?.hardwareAddress
                ?.joinToString(":") { "%02x".format(it) }
                ?.let { add(it) }

            // OS info
            add(System.getProperty("os.name", "unknown"))
            add(System.getProperty("os.arch", "unknown"))

            // Available processors (stable across reboots)
            add(Runtime.getRuntime().availableProcessors().toString())

            // Username (ties to server operator)
            add(System.getProperty("user.name", "unknown"))
        }

        // Hash the components into a stable fingerprint
        val digest = MessageDigest.getInstance("SHA-256")
        digest.update(components.joinToString("|").toByteArray())
        return digest.digest().joinToString("") { "%02x".format(it) }.take(32)
    }
}
```

### Time-Limited Trials

Use server-provided timestamps (not local clock) to prevent clock manipulation:

```kotlin
class TrialManager(private val plugin: JavaPlugin) {

    private val trialFile = File(plugin.dataFolder, ".trial")

    suspend fun isTrialValid(): Boolean {
        if (!trialFile.exists()) {
            val serverTime = fetchServerTime()
            trialFile.writeText(serverTime.toString())
            return true
        }

        val startTime = trialFile.readText().toLongOrNull() ?: return false
        val currentTime = fetchServerTime()
        val trialDays = 7L
        val elapsed = currentTime - startTime

        return elapsed < (trialDays * 86_400_000L)
    }

    private suspend fun fetchServerTime(): Long = withContext(Dispatchers.IO) {
        // Fetch from your server or NTP. Never trust System.currentTimeMillis()
        // for trial enforcement -- users can set their clock back.
        val url = URI("https://your-server.com/time").toURL()
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 3_000
        val body = conn.inputStream.bufferedReader().readText()
        body.trim().toLong()
    }
}
```

### Self-JAR Checksum

Detect if the JAR has been modified (classes patched to bypass license checks):

```kotlin
import java.security.MessageDigest
import java.util.jar.JarFile

object IntegrityChecker {

    /**
     * Computes a SHA-256 checksum over all .class entries in the JAR.
     * Compare against a known-good value fetched from your license server.
     */
    fun computeJarChecksum(jarPath: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        JarFile(jarPath).use { jar ->
            jar.entries().asSequence()
                .filter { it.name.endsWith(".class") }
                .sortedBy { it.name } // deterministic order
                .forEach { entry ->
                    jar.getInputStream(entry).use { stream ->
                        digest.update(stream.readBytes())
                    }
                }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun getCurrentJarPath(clazz: Class<*>): String? {
        return clazz.protectionDomain?.codeSource?.location?.toURI()?.path
    }
}
```

### Warning About Client-Side-Only Checks

Any check that runs entirely inside the JVM the attacker controls can be patched:

```kotlin
// THIS IS TRIVIALLY DEFEATED:
fun checkLicense(): Boolean {
    // Attacker replaces entire method body with: return true
    return storedKey == expectedKey
}
```

A reverse engineer can decompile despite obfuscation, find the boolean-returning method, replace the body with `return true` using a bytecode editor, and repackage the JAR. Server-side validation is the only mechanism that resists this because the validation logic runs on infrastructure the attacker does not control.

---

## Quick Reference Card

| Goal | ProGuard Flag |
|------|---------------|
| Keep a class entirely | `-keep class com.x.Y { *; }` |
| Keep only if members match | `-keepclasseswithmembers class * { ... }` |
| Keep members only (class can rename) | `-keepclassmembers class * { ... }` |
| Prevent obfuscation but allow shrinking | `-keepnames class com.x.Y` |
| Custom obfuscation dictionary | `-obfuscationdictionary dict.txt` |
| Preserve line numbers | `-keepattributes SourceFile,LineNumberTable` |
| Suppress warnings | `-dontwarn com.example.**` |
| Skip optimization | `-dontoptimize` |
| Skip obfuscation | `-dontobfuscate` |
| Output mapping file | `-printmapping mapping.txt` |
| Number of optimization passes | `-optimizationpasses 5` |
| Repackage into root package | `-repackageclasses ''` |
| Allow access modification | `-allowaccessmodification` |

### Troubleshooting Checklist

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ClassNotFoundException` at runtime | Main class renamed | `-keep` for plugin main class |
| Events not firing | `@EventHandler` methods renamed | `-keepclassmembers` for `@EventHandler` |
| Commands not responding | `CommandExecutor` renamed | `-keep` for `CommandExecutor` impls |
| `Duplicate key` on Paper 1.21+ | Kotlin metadata conflict | Keep `kotlin.reflect.**` |
| Config fails to load | `ConfigurationSerializable` renamed | Keep serializable classes with fields |
| Coroutines crash | Coroutine internals stripped | `-dontwarn kotlinx.coroutines.**` |
| `NoSuchMethodError` | Method signature mismatch | Keep the specific method signature |
| JAR size increased | Library JARs as injars | Move to libraryjars |
