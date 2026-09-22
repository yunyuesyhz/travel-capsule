package com.trailcapsule.trail_capsule

import java.io.File
import java.io.IOException

/** Resolves files only after both the candidate and allowed roots are canonicalized. */
internal object AppFilePolicy {
    fun resolveReadable(
        path: String?,
        roots: Iterable<File>,
        requiredExtension: String? = null,
    ): File? {
        if (path.isNullOrBlank()) return null
        val candidate = try {
            File(path).canonicalFile
        } catch (_: IOException) {
            return null
        } catch (_: SecurityException) {
            return null
        }
        if (!candidate.isFile || !candidate.canRead()) return null
        if (requiredExtension != null &&
            !candidate.extension.equals(requiredExtension, ignoreCase = true)
        ) return null

        return if (roots.any { root -> isWithin(root, candidate) }) candidate else null
    }

    internal fun isWithin(root: File, candidate: File): Boolean = try {
        val rootPath = root.canonicalFile.path
        val candidatePath = candidate.canonicalFile.path
        candidatePath == rootPath || candidatePath.startsWith(rootPath + File.separator)
    } catch (_: IOException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
