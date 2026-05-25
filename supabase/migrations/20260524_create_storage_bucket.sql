-- 创建聊天媒体存储桶
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-media', 'chat-media', true)
ON CONFLICT (id) DO NOTHING;

-- 允许认证用户上传文件
CREATE POLICY "Authenticated users can upload chat media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'chat-media');

-- 允许所有人查看公开文件
CREATE POLICY "Anyone can view chat media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-media');

-- 允许用户删除自己上传的文件
CREATE POLICY "Users can delete their own chat media"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'chat-media' AND auth.uid()::text = owner);
