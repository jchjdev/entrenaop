import { billingConfig } from "../_shared/billing_config.ts";
import { handle } from "../_shared/revenuecat.ts";
Deno.serve((request) => handle(request, billingConfig(), "sync"));
