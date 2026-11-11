import { IsIn, IsInt, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export const attachmentMimeTypes = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
] as const;

export class CreateAttachmentUploadDto {
  @IsIn(['EXPENSE', 'TRANSFER'])
  targetType!: 'EXPENSE' | 'TRANSFER';

  @IsUUID()
  targetId!: string;

  @IsString()
  @MaxLength(255)
  fileName!: string;

  @IsIn(attachmentMimeTypes)
  mimeType!: (typeof attachmentMimeTypes)[number];

  @IsInt()
  @Min(1)
  @Max(10 * 1024 * 1024)
  fileSize!: number;
}
