/// Versión de un objeto de Storage (su ETag, o la fecha de subida). El
/// teléfono la incluye en la clave de caché: si se reemplaza el archivo con
/// el mismo nombre, cambia la versión y se vuelve a descargar.
/// Devuelve "" si no se puede consultar; el audio se sirve igual.
export async function objectVersion(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucket: string,
  path: string,
): Promise<string> {
  const slash = path.lastIndexOf("/");
  const name = path.slice(slash + 1);
  try {
    const result = await fetch(
      `${supabaseUrl}/storage/v1/object/list/${encodeURIComponent(bucket)}`,
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prefix: slash < 0 ? "" : path.slice(0, slash),
          search: name,
          limit: 100,
        }),
      },
    );
    if (!result.ok) return "";
    const items = await result.json() as {
      name?: string;
      updated_at?: string;
      metadata?: { eTag?: string };
    }[];
    const item = items.find((entry) => entry.name === name);
    return (item?.metadata?.eTag ?? item?.updated_at ?? "").replaceAll('"', "");
  } catch {
    return "";
  }
}
