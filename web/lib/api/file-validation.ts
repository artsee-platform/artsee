const FILE_SIGNATURES: Record<string, (bytes: Uint8Array) => boolean> = {
  "image/jpeg": (bytes) =>
    bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff,
  "image/png": (bytes) =>
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a,
  "image/webp": (bytes) =>
    bytes.length >= 12 &&
    ascii(bytes, 0, 4) === "RIFF" &&
    ascii(bytes, 8, 12) === "WEBP",
  "image/gif": (bytes) => {
    const signature = ascii(bytes, 0, 6);
    return signature === "GIF87a" || signature === "GIF89a";
  },
  "application/pdf": (bytes) => ascii(bytes, 0, Math.min(bytes.length, 1024)).includes("%PDF-"),
};

function ascii(bytes: Uint8Array, start: number, end: number) {
  return String.fromCharCode(...bytes.slice(start, end));
}

export function hasSupportedFileSignature(bytes: Uint8Array, contentType: string) {
  const validate = FILE_SIGNATURES[contentType.toLowerCase()];
  return validate ? validate(bytes) : false;
}

