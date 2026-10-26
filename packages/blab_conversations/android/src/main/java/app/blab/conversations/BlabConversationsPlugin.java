package app.blab.conversations;

import android.app.Person;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.graphics.BitmapFactory;
import android.view.View;
import android.widget.RemoteViews;
import android.content.Context;
import android.content.Intent;
import android.content.LocusId;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.drawable.Icon;
import android.os.Build;
import java.io.ByteArrayOutputStream;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Only display metadata; routing authorization stays in PushTapRouter. */
public final class BlabConversationsPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private Context context;
    private MethodChannel channel;

    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "blab/conversations");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        context = null;
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "prepare": result.success(prepare(call)); break;
                case "showCustomProbe":
                case "showCustom": showCustomProbe(call); result.success(null); break;
                case "remove": remove((String) call.arguments); result.success(null); break;
                case "clear": clear(); result.success(null); break;
                default: result.notImplemented();
            }
        } catch (Exception error) {
            result.error("conversation_unavailable", "Conversation metadata unavailable", null);
        }
    }
    private Bitmap avatar(String initials, int color) {
        Bitmap bitmap = Bitmap.createBitmap(208, 208, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(color);
        canvas.drawCircle(104, 104, 104, paint);
        paint.setColor(Color.WHITE);
        paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        paint.setTextSize(72);
        paint.setTextAlign(Paint.Align.CENTER);
        while (paint.measureText(initials) > 174 && paint.getTextSize() > 24) {
            paint.setTextSize(paint.getTextSize() - 2);
        }
        Paint.FontMetrics metrics = paint.getFontMetrics();
        canvas.drawText(initials, 104, 104 - (metrics.ascent + metrics.descent) / 2, paint);
        return bitmap;
    }
    private byte[] png(Bitmap bitmap) {
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
        return stream.toByteArray();
    }
    private Map<String, Object> prepare(MethodCall call) {
        String id = call.argument("id");
        String name = call.argument("name");
        String sender = call.argument("sender");
        String payload = call.argument("payload");
        if (id == null || !id.startsWith("blab:") || name == null || name.isBlank() || payload == null) {
            throw new IllegalArgumentException();
        }
        Number color = call.argument("color");
        Number senderColor = call.argument("senderColor");
        Bitmap icon = avatar(call.argument("initials"), color.intValue());
        Bitmap senderIcon = avatar(call.argument("senderInitials"), senderColor.intValue());
        Map<String, Object> response = new HashMap<>();
        response.put("icon", png(icon));
        response.put("senderIcon", png(senderIcon));
        // API30+ requires a long-lived shortcut to qualify as a conversation.
        if (Build.VERSION.SDK_INT >= 30) {
            Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (intent != null) {
                intent.setAction("SELECT_NOTIFICATION");
                intent.putExtra("payload", payload);
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                Person person = new Person.Builder().setName(sender)
                    .setKey(call.argument("senderKey"))
                    .setIcon(Icon.createWithBitmap(senderIcon)).build();
                ShortcutInfo shortcut = new ShortcutInfo.Builder(context, id)
                    .setShortLabel(name).setLongLabel(name)
                    .setIcon(Icon.createWithAdaptiveBitmap(icon))
                    .setIntent(intent).setPersons(new Person[] {person}).setLongLived(true)
                    .setLocusId(new LocusId(id)).build();
                ShortcutManager manager = context.getSystemService(ShortcutManager.class);
                manager.pushDynamicShortcut(shortcut);
                // Only claim the ID if the system accepted it; rate-limits may suppress it.
                if (manager.getDynamicShortcuts().stream().anyMatch(s -> s.getId().equals(id))) {
                    response.put("shortcutId", id);
                }
            }
        }
        icon.recycle();
        senderIcon.recycle();
        return response;
    }
    // Same rendering path for approved incoming notifications and native QA fixtures.
    private void showCustomProbe(MethodCall call) {
        Number idValue = call.argument("id");
        int id = idValue.intValue();
        String title = call.argument("title");
        String body = call.argument("body");
        boolean privatePreview = Boolean.TRUE.equals(call.argument("private"));
        byte[] artwork = call.argument("artwork");
        Bitmap badge = BitmapFactory.decodeByteArray(artwork, 0, artwork.length);
        if (badge == null || title == null || body == null) throw new IllegalArgumentException();
        Number color = call.argument("color");
        Bitmap initials = privatePreview ? badge : avatar(call.argument("initials"), color.intValue());
        RemoteViews compact = customView(R.layout.blab_notification_content, title, body, initials, badge, privatePreview);
        RemoteViews expanded = customView(R.layout.blab_notification_expanded, title, body, initials, badge, privatePreview);
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(new NotificationChannel("messages", "Messages", NotificationManager.IMPORTANCE_HIGH));
        }
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(context, "messages") : new Notification.Builder(context);
        int smallIcon = context.getResources().getIdentifier("ic_notification_arrow", "drawable", context.getPackageName());
        Intent open = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (open == null) throw new IllegalStateException();
        open.setAction("SELECT_NOTIFICATION");
        open.putExtra("payload", (String) call.argument("payload"));
        PendingIntent pending = PendingIntent.getActivity(context, id, open,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        builder.setSmallIcon(smallIcon).setColor(0xFFF88C5A)
            .setContentTitle(title).setContentText(body)
            .setCategory(Notification.CATEGORY_MESSAGE).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(pending)
            .setStyle(new Notification.DecoratedCustomViewStyle())
            .setCustomContentView(compact).setCustomBigContentView(expanded)
            .setCustomHeadsUpContentView(compact);
        String tag = call.argument("tag");
        manager.notify(tag != null ? tag : "blab-custom-probe", id, builder.build());
        // RemoteViews parcel their bitmap data before this synchronous return.
        if (initials != badge) initials.recycle();
        badge.recycle();
    }
    private RemoteViews customView(int layout, String title, String body, Bitmap avatar,
            Bitmap badge, boolean privatePreview) {
        RemoteViews view = new RemoteViews(context.getPackageName(), layout);
        view.setImageViewBitmap(R.id.blab_avatar, avatar);
        view.setImageViewBitmap(R.id.blab_badge, badge);
        view.setViewVisibility(R.id.blab_badge, privatePreview ? View.GONE : View.VISIBLE);
        view.setTextViewText(R.id.blab_title, title);
        view.setTextViewText(R.id.blab_body, body);
        return view;
    }
    private void remove(String id) {
        if (Build.VERSION.SDK_INT >= 25 && id != null && id.startsWith("blab:")) {
            ShortcutManager manager = context.getSystemService(ShortcutManager.class);
            manager.removeDynamicShortcuts(Collections.singletonList(id));
            if (Build.VERSION.SDK_INT >= 30) manager.removeLongLivedShortcuts(Collections.singletonList(id));
        }
    }
    private void clear() {
        if (Build.VERSION.SDK_INT < 25) return;
        ShortcutManager manager = context.getSystemService(ShortcutManager.class);
        for (ShortcutInfo shortcut : manager.getDynamicShortcuts()) {
            if (shortcut.getId().startsWith("blab:")) remove(shortcut.getId());
        }
        if (Build.VERSION.SDK_INT >= 30) {
            for (ShortcutInfo shortcut : manager.getShortcuts(ShortcutManager.FLAG_MATCH_CACHED)) {
                if (shortcut.getId().startsWith("blab:")) remove(shortcut.getId());
            }
        }
    }
}
