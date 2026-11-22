import { NextFunction, Request, Response } from 'express';
import { AnyZodObject, ZodEffects, ZodSchema } from 'zod';

type ValidatableSchema = AnyZodObject | ZodEffects<AnyZodObject> | ZodSchema;

export function validateBody(schema: ValidatableSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      next(err);
    }
  };
}

export function validateQuery(schema: ValidatableSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      req.query = schema.parse(req.query);
      next();
    } catch (err) {
      next(err);
    }
  };
}

export function validateParams(schema: ValidatableSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      req.params = schema.parse(req.params);
      next();
    } catch (err) {
      next(err);
    }
  };
}
