export class TrainingError extends Error {
  constructor(code:string){super(code);this.name='TrainingError';}
}
