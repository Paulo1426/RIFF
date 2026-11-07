/// Límite de tasa de ventana deslizante en memoria.
// shortcut: limite por instancia, cada instancia cuenta aparte; migrar a almacenamiento compartido (Redis/Firestore) si hace falta un tope global.
export class LimiteTasa {
  private golpes = new Map<string, number[]>();
  private ultimaLimpieza = 0;

  constructor(readonly max: number, readonly ventanaMs = 60_000) {}

  /// Registra una petición de [clave]. Devuelve 0 si pasa, o los segundos
  /// que faltan para poder volver a intentarlo.
  consumir(clave: string, ahora = Date.now()): number {
    this.limpiar(ahora);
    const desde = ahora - this.ventanaMs;
    const recientes = (this.golpes.get(clave) ?? []).filter((t) => t > desde);
    if (recientes.length >= this.max) {
      this.golpes.set(clave, recientes);
      return Math.max(
        1,
        Math.ceil((recientes[0] + this.ventanaMs - ahora) / 1000),
      );
    }
    recientes.push(ahora);
    this.golpes.set(clave, recientes);
    return 0;
  }

  private limpiar(ahora: number): void {
    if (ahora - this.ultimaLimpieza < this.ventanaMs) return;
    this.ultimaLimpieza = ahora;
    for (const [clave, tiempos] of this.golpes) {
      if (tiempos[tiempos.length - 1] <= ahora - this.ventanaMs) {
        this.golpes.delete(clave);
      }
    }
  }

  get tamano(): number {
    return this.golpes.size;
  }
}
