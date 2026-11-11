import { IsOptional, IsString, Matches, MaxLength, IsUUID } from 'class-validator';

export class CreateTransferDto {
  @IsUUID()
  childId!: string;

  @IsString()
  @Matches(/^(?:0|[1-9]\d{0,13})$/)
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class RejectTransferDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
