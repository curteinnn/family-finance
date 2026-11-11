import { IsDateString, IsOptional, IsString, IsUUID, Matches, MaxLength } from 'class-validator';

export class CreateExpenseDto {
  @IsUUID()
  categoryId!: string;

  @IsString()
  @Matches(/^(?:0|[1-9]\d{0,13})$/)
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsDateString()
  spentAt?: string;
}

export class VoidExpenseDto {
  @IsString()
  @MaxLength(500)
  reason!: string;
}
