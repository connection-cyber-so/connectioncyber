export type PortalHostname =
  | { kind: 'central'; hostname: string }
  | { kind: 'tenant-candidate'; hostname: string }
  | { kind: 'invalid'; hostname: null };

type HostnameOptions = {
  centralHostnames: readonly string[];
  allowLocalhost?: boolean;
};

const IPV4_PATTERN = /^\d{1,3}(?:\.\d{1,3}){3}$/;
const PORT_PATTERN = /:\d{1,5}$/;

export function normalizeHostname(rawHostname: string | null | undefined): string | null {
  if (!rawHostname) return null;

  let hostname = rawHostname.trim().toLowerCase();
  if (!hostname || hostname.startsWith('[')) return null;

  const portMatch = hostname.match(PORT_PATTERN);
  if (portMatch) hostname = hostname.slice(0, -portMatch[0].length);

  hostname = hostname.replace(/\.$/, '');
  if (!hostname || hostname.length > 253 || hostname.includes(':')) return null;
  if (hostname === 'localhost' || hostname === '127.0.0.1') return hostname;
  if (IPV4_PATTERN.test(hostname)) return null;

  const labels = hostname.split('.');
  if (labels.length < 2) return null;

  const valid = labels.every(
    (label) =>
      label.length >= 1 &&
      label.length <= 63 &&
      /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(label)
  );

  return valid ? hostname : null;
}

export function classifyPortalHostname(
  rawHostname: string | null | undefined,
  options: HostnameOptions
): PortalHostname {
  const hostname = normalizeHostname(rawHostname);
  if (!hostname) return { kind: 'invalid', hostname: null };

  const centralHosts = options.centralHostnames
    .map((item) => normalizeHostname(item))
    .filter((item): item is string => Boolean(item));

  if (centralHosts.includes(hostname)) return { kind: 'central', hostname };

  if (
    options.allowLocalhost &&
    (hostname === 'localhost' || hostname === '127.0.0.1')
  ) {
    return { kind: 'central', hostname };
  }

  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return { kind: 'invalid', hostname: null };
  }

  return { kind: 'tenant-candidate', hostname };
}
