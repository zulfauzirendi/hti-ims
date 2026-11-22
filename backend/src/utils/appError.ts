export type ErrorCode =
  | 'SAFETY_PHOTO_REQUIRED'
  | 'INSUFFICIENT_STOCK'
  | 'TRANSFER_SAME_LOCATION'
  | 'TRANSFER_INVALID_STATE'
  | 'ITEM_HAS_ACTIVE_STOCK'
  | 'AUTH_INVALID_CREDENTIALS'
  | 'AUTH_TOKEN_EXPIRED'
  | 'AUTH_TOKEN_REUSE_DETECTED'
  | 'AUTH_ACCOUNT_INACTIVE'
  | 'AUTH_MUST_CHANGE_PASSWORD'
  | 'RBAC_ROLE_DENIED'
  | 'RBAC_LOCATION_DENIED'
  | 'RESOURCE_NOT_FOUND'
  | 'STOCK_VERSION_CONFLICT'
  | 'DUPLICATE_RESOURCE'
  | 'UPLOAD_FILE_TOO_LARGE'
  | 'UPLOAD_INVALID_MAGIC_BYTES'
  | 'VALIDATION_ERROR'
  | 'RATE_LIMIT_EXCEEDED'
  | 'SERVICE_MAINTENANCE'
  | 'INTERNAL_SERVER_ERROR';

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: ErrorCode;
  public readonly details?: unknown;

  constructor(statusCode: number, code: ErrorCode, message: string, details?: unknown) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}
