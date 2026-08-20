package com.artsee.artsee_app

import com.tencent.chat.flutter.push.tencent_cloud_chat_push.application.TencentCloudChatPushApplication

/// TIMPush needs an application-level listener so notification clicks can be
/// retained while Flutter is starting from a terminated state.
class ArtseeApplication : TencentCloudChatPushApplication() {
    override fun onCreate() {
        super.onCreate()
    }
}
