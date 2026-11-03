// Minijuego "Adivina la intro": cada nivel adivinado por primera vez da
// monedas según su dificultad y cada intro cuesta una moneda. Con 5 niveles
// por dificultad se ganan 5×2 + 5×3 + 5×4 = 45, justo lo que cuestan las 45
// intros.
export const introCoinRewards = { facil: 2, medio: 3, avanzado: 4 } as const;
export const introPrice = 1;

// Bono de bienvenida al crear una cuenta o reiniciar el progreso: 10 monedas.
export const welcomeCoins = 10;

/// Bono de bienvenida guardado en los estados de intro de todos los géneros.
export function savedWelcomeCoins(
  states: readonly {
    bonoBienvenida?: unknown;
    monedasBienvenida?: unknown;
  }[],
): number {
  return states.reduce((coins, state) => {
    const welcome = state.monedasBienvenida;
    if (state.bonoBienvenida !== true || typeof welcome !== "number") {
      return coins;
    }
    return Math.max(coins, welcome);
  }, 0);
}

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

/// Saldo disponible: lo ganado menos lo gastado en intros desbloqueadas y pistas.
/// [welcome] son las monedas de bienvenida guardadas en los estados de intro.
export function coinBalance(
  earned: number,
  unlockedCount: number,
  hintCoinsSpent = 0,
  welcome = 0,
): number {
  return Math.max(0, earned + welcome - unlockedCount * introPrice - hintCoinsSpent);
}
