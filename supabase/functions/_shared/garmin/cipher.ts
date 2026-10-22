// AES-GCM autentica también la cuenta, generación y finalidad del contenido.
// La clave de 32 bytes se configura como secreto Edge; nunca se envía a Flutter.
function encode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
function decode(value: string) {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("invalid_ciphertext");
  return Uint8Array.from(atob(value.replaceAll("-", "+").replaceAll("_", "/")), c => c.charCodeAt(0));
}
export class GarminCipher {
  private readonly key: Promise<CryptoKey>;
  constructor(secret: string) {
    const bytes = decode(secret);
    if (bytes.length !== 32 || encode(bytes) !== secret) throw new Error("invalid_encryption_key");
    this.key = crypto.subtle.importKey("raw", bytes, "AES-GCM", false, ["encrypt", "decrypt"]);
  }
  async seal(value: unknown, context: string): Promise<string> {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const bytes = new TextEncoder().encode(JSON.stringify(value));
    if (bytes.length > 20000) throw new Error("invalid_ciphertext");
    const cipher = await crypto.subtle.encrypt({name: "AES-GCM", iv,
      additionalData: new TextEncoder().encode(context)}, await this.key, bytes);
    return `v1.${encode(iv)}.${encode(new Uint8Array(cipher))}`;
  }
  async open<T>(value: string, context: string): Promise<T> {
    try {
      if (value.length > 32768) throw new Error();
      const [version, iv, data, extra] = value.split(".");
      if (version !== "v1" || extra !== undefined || decode(iv).length !== 12) throw new Error();
      const bytes = await crypto.subtle.decrypt({name: "AES-GCM", iv: decode(iv),
        additionalData: new TextEncoder().encode(context)}, await this.key, decode(data));
      return JSON.parse(new TextDecoder().decode(bytes)) as T;
    } catch { throw new Error("invalid_ciphertext"); }
  }
}

export async function garminStateHash(state: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(state));
  return [...new Uint8Array(hash)].map(x => x.toString(16).padStart(2, "0")).join("");
}
