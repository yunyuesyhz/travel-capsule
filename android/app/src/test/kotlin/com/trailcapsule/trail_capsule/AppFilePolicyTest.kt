package com.trailcapsule.trail_capsule

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppFilePolicyTest {
    @Test
    fun canonicalizesAnEquivalentRootBeforeCheckingTheFile() {
        val parent = Files.createTempDirectory("capsule-policy").toFile()
        try {
            val realRoot = parent.resolve("real").apply { mkdirs() }
            val pdf = realRoot.resolve("ticket.pdf").apply { writeText("pdf") }
            val alias = parent.resolve("alias")
            Files.createSymbolicLink(alias.toPath(), realRoot.toPath())

            assertEquals(
                pdf.canonicalFile,
                AppFilePolicy.resolveReadable(pdf.path, listOf(alias), "pdf"),
            )
        } finally {
            parent.deleteRecursively()
        }
    }

    @Test
    fun rejectsSiblingPrefixMissingFileAndWrongExtension() {
        val parent = Files.createTempDirectory("capsule-policy").toFile()
        try {
            val root = parent.resolve("data").apply { mkdirs() }
            val siblingPdf = parent.resolve("data-copy/ticket.pdf").apply {
                parentFile!!.mkdirs()
                writeText("pdf")
            }
            val image = root.resolve("ticket.jpg").apply { writeText("image") }

            assertNull(AppFilePolicy.resolveReadable(siblingPdf.path, listOf(root), "pdf"))
            assertNull(AppFilePolicy.resolveReadable(root.resolve("missing.pdf").path, listOf(root), "pdf"))
            assertNull(AppFilePolicy.resolveReadable(image.path, listOf(root), "pdf"))
        } finally {
            parent.deleteRecursively()
        }
    }
}
