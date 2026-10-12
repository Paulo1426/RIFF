// Minijuego "Adivina la intro": cada nivel adivinado por primera vez da
// monedas según su dificultad y cada intro cuesta una moneda. Con 5 niveles
// por dificultad se ganan 5×2 + 5×3 + 5×4 = 45, justo lo que cuestan las 45
// intros.
export const introCoinRewards = { facil: 2, medio: 3, avanzado: 4 } as const;
export const introPrice = 1;

/// Monedas ganadas a partir de los niveles completados de cada dificultad.
/// Repetir un nivel no suma: se cuentan ids únicos.
export function coinsEarned(
  completedByDifficulty: Partial<
    Record<keyof typeof introCoinRewards, readonly string[]>
  >,
): number {
  return Object.entries(introCoinRewards).reduce(
    (total, [difficulty, reward]) =>
      total +
      new Set(
        completedByDifficulty[difficulty as keyof typeof introCoinRewards] ??
          [],
      ).size * reward,
    0,
  );
}

/// Saldo disponible: lo ganado menos lo gastado en intros desbloqueadas.
export function coinBalance(earned: number, unlockedCount: number): number {
  return Math.max(0, earned - unlockedCount * introPrice);
}
