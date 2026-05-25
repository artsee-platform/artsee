# 实时聊天系统使用指南

## 🎉 功能特性

### ✅ 已实现
1. **Supabase Realtime 消息** - 实时接收新消息
2. **文本消息** - 发送和接收文本
3. **图片消息** - 从相册选择图片发送
4. **语音消息** - 长按录音，松开发送
5. **输入状态提示** - "正在输入..." 实时显示
6. **已读状态** - 自动标记消息为已读
7. **消息气泡** - 区分发送/接收样式
8. **时间显示** - 智能格式化
9. **头像显示** - 支持图片和图标

## 📋 使用步骤

### 1. 运行 Storage 迁移

在 Supabase Dashboard → SQL Editor 中执行：

```bash
cd /Users/tom/Desktop/artsee
# 在 Supabase Dashboard 执行
supabase/migrations/20260524_create_storage_bucket.sql
```

### 2. 创建测试会话

在 Supabase Dashboard → SQL Editor 中执行：

```sql
-- 创建测试会话
INSERT INTO conversations (id, type, name)
VALUES 
  ('test-ai-chat', 'ai', 'Artiqore AI'),
  ('test-teacher-chat', 'direct', '导师王教授')
ON CONFLICT (id) DO NOTHING;

-- 添加当前用户为参与者（替换 YOUR_USER_ID）
INSERT INTO conversation_participants (conversation_id, user_id)
VALUES 
  ('test-ai-chat', 'YOUR_USER_ID'),
  ('test-teacher-chat', 'YOUR_USER_ID')
ON CONFLICT (conversation_id, user_id) DO NOTHING;
```

### 3. 更新消息列表页

修改 `messages_screen.dart`，使用真实的 conversation_id：

```dart
// 在 _MessageTile 的 onTap 中
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ChatRealtimeScreen(
      conversationId: 'test-ai-chat', // 使用真实 ID
      chatName: item.title,
      avatarIcon: item.icon,
      avatarColor: _messageAccent(item),
    ),
  ),
);
```

### 4. 测试功能

#### 文本消息
1. 打开聊天页面
2. 输入文字
3. 点击发送按钮
4. 查看"正在输入..."提示

#### 图片消息
1. 点击图片图标
2. 从相册选择图片
3. 等待上传完成
4. 查看图片消息

#### 语音消息
1. **长按**麦克风图标开始录音
2. 看到"正在录音..."提示
3. **松开**自动发送
4. 点击语音消息播放

## 🔧 权限配置

### iOS (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来录制语音消息</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要相册权限来发送图片</string>
```

### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

## 📊 数据库表结构

### conversations
- `id` - 会话 ID
- `type` - 类型 (direct, group, ai, system)
- `name` - 会话名称
- `avatar_url` - 头像 URL

### messages
- `id` - 消息 ID
- `conversation_id` - 所属会话
- `sender_id` - 发送者 ID
- `content` - 文本内容
- `message_type` - 类型 (text, image, voice, file)
- `media_url` - 媒体 URL
- `media_duration` - 语音时长

### typing_indicators
- `conversation_id` - 会话 ID
- `user_id` - 用户 ID
- `started_at` - 开始时间

## 🎨 UI 组件

### ChatRealtimeScreen
主聊天页面，包含：
- AppBar - 显示对方信息和输入状态
- 消息列表 - 滚动显示历史消息
- 输入栏 - 文本输入、图片、语音

### _MessageBubble
消息气泡组件，支持：
- 文本消息
- 图片消息（可点击查看）
- 语音消息（可点击播放）

## 🚀 高级功能

### 1. 自定义消息类型

```dart
// 在 MessageService 中添加
Future<Message> sendCustomMessage(
  String conversationId,
  String customType,
  Map<String, dynamic> data,
) async {
  final response = await _supabase.from('messages').insert({
    'conversation_id': conversationId,
    'sender_id': _supabase.auth.currentUser?.id,
    'message_type': customType,
    'metadata': data,
  }).select().single();
  
  return Message.fromJson(response);
}
```

### 2. 消息撤回

```dart
Future<void> deleteMessage(String messageId) async {
  await _supabase
      .from('messages')
      .delete()
      .eq('id', messageId);
}
```

### 3. 群聊支持

```dart
// 创建群聊
Future<Conversation> createGroupChat(
  String name,
  List<String> userIds,
) async {
  final conversation = await _supabase.from('conversations').insert({
    'type': 'group',
    'name': name,
  }).select().single();
  
  // 添加参与者
  for (final userId in userIds) {
    await _supabase.from('conversation_participants').insert({
      'conversation_id': conversation['id'],
      'user_id': userId,
    });
  }
  
  return Conversation.fromJson(conversation);
}
```

## 🐛 常见问题

### Q: 消息发送失败？
A: 检查：
1. 用户是否已登录
2. 用户是否在 conversation_participants 中
3. Storage bucket 是否已创建
4. RLS 策略是否正确

### Q: 图片上传失败？
A: 检查：
1. Storage bucket 权限
2. 文件大小限制
3. 网络连接

### Q: 语音录制失败？
A: 检查：
1. 麦克风权限
2. iOS/Android 配置
3. 录音格式支持

### Q: Realtime 不工作？
A: 检查：
1. Supabase Realtime 是否启用
2. 表的 RLS 策略
3. 订阅是否正确取消

## 📝 下一步优化

- [ ] 消息已读回执（双勾）
- [ ] 消息引用/回复
- [ ] 表情反应
- [ ] 文件发送
- [ ] 视频消息
- [ ] 消息搜索
- [ ] 聊天记录导出
- [ ] 消息加密

## 🎯 性能优化

1. **分页加载** - 只加载最近 50 条消息
2. **图片压缩** - 上传前压缩图片
3. **语音压缩** - 使用 AAC 格式
4. **缓存策略** - 缓存已加载的消息
5. **懒加载** - 滚动时加载更多

## 📚 参考资料

- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [Flutter Image Picker](https://pub.dev/packages/image_picker)
- [Flutter Audio Recorder](https://pub.dev/packages/record)
- [Flutter Audio Player](https://pub.dev/packages/audioplayers)
