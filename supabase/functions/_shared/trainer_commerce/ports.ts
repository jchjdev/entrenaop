import type {
  Binding,
  CheckoutReference,
  Command,
  CommandRecord,
  Context,
  Decision,
  Lease,
  ProviderSnapshot,
  SimulationPolicy,
  VerifiedSignal,
} from "./model.ts";

export interface CommercialProviderPort {
  prepareCheckout(command: Command): Promise<CheckoutReference>;
  recoverCheckout(command: Command): Promise<CheckoutReference | null>;
  readCanonical(context: Context): Promise<ProviderSnapshot>;
}
export interface VerifyEventPort {
  // Infraestructura verifica cuerpo original, firma, entorno y cuenta antes de devolver la señal.
  verify(input: { body: string; proof: string }): Promise<VerifiedSignal>;
}
export interface CommercialStorePort {
  binding(context: Context): { value: Binding; revision: number };
  recordCommand(command: Command): CommandRecord;
  claimCommand(id: string): boolean;
  completeCommand(id: string, reference: CheckoutReference): void;
  uncertainCommand(id: string): void;
  command(id: string): CommandRecord;
  acceptVerifiedEvent(signal: VerifiedSignal): "new" | "duplicate";
  claimReconciliation(context: Context, now: number, ttl: number): Lease | null;
  commitFactsAndDecision(
    lease: Lease,
    snapshot: ProviderSnapshot,
    policy: SimulationPolicy | null,
    now: number,
  ): Decision;
  releaseReconciliation(lease: Lease): void;
}
