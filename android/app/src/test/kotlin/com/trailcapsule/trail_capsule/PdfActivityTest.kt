package com.trailcapsule.trail_capsule

import android.content.Intent
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26, 35])
class PdfActivityTest {
    @Test
    fun missingPdfShowsAnErrorWithoutClosingTheActivity() {
        val activity = Robolectric.buildActivity(
            PdfActivity::class.java,
            Intent().putExtra("path", "/missing/travel.pdf").putExtra("title", "行程资料"),
        ).setup().get()

        assertFalse(activity.isFinishing)
        assertTrue(activity.findViewById<View>(android.R.id.content).containsText("无法预览"))
        activity.finish()
    }

    private fun View.containsText(expected: String): Boolean = when (this) {
        is TextView -> text.toString().contains(expected)
        is ViewGroup -> (0 until childCount).any { getChildAt(it).containsText(expected) }
        else -> false
    }
}
