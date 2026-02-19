-- 채팅 첨부 버킷에 동영상 MIME 타입 허용 (이미지 + 동영상)
UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg', 'image/png', 'image/gif', 'image/webp',
  'video/mp4', 'video/quicktime', 'video/webm', 'video/x-m4v'
]::text[]
WHERE id = 'chat-attachments';
