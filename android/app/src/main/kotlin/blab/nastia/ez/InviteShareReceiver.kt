package blab.nastia.ez

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.chooser.ChooserResult

class InviteShareReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val callback = onChosen ?: return
        if (Build.VERSION.SDK_INT >= 35) {
            val result = intent.getParcelableExtra(Intent.EXTRA_CHOOSER_RESULT, ChooserResult::class.java)
            if (result != null) {
                callback(intent.getIntExtra("request", -1), result.type == ChooserResult.CHOOSER_RESULT_COPY ||
                    result.type == ChooserResult.CHOOSER_RESULT_SELECTED_COMPONENT)
                return
            }
        }
        @Suppress("DEPRECATION")
        val component = intent.getParcelableExtra<ComponentName>(Intent.EXTRA_CHOSEN_COMPONENT)
        if (component != null) callback(intent.getIntExtra("request", -1), true)
    }

    companion object {
        var onChosen: ((Int, Boolean) -> Unit)? = null
    }
}
