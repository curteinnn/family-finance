import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  token!: string;

  @IsIn(['ANDROID', 'IOS'])
  platform!: 'ANDROID' | 'IOS';
}

export class RemoveDeviceTokenDto {
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  token!: string;
}
