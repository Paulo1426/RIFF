// Minijuego "Adivina la intro": cada nivel adivinado por primera vez da
// monedas según su dificultad y cada intro cuesta una moneda.
export const introCoinRewards = { facil: 2, medio: 3, avanzado: 4 } as const;
export const introPrice = 1;
// Moneda del género (o Medley) por cada intro adivinada.
export const introGuessReward = 1;
export const introsPerGenre = 30;
export const introsPerGenreInMedley = 15;
export const introsInMedley = 75;

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

/// Calcula por separado las monedas ganadas en cada género.
export function coinsEarnedByGenre(
  completedByGenre: Readonly<
    Record<
      string,
      Partial<Record<keyof typeof introCoinRewards, readonly string[]>>
    >
  >,
): Record<string, number> {
  return Object.fromEntries(
    Object.entries(completedByGenre).map(([genre, completed]) => [
      genre,
      coinsEarned(completed),
    ]),
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
  return Math.max(
    0,
    earned + welcome - unlockedCount * introPrice - hintCoinsSpent,
  );
}

/// Saldo de una cartera de género con sus gastos de intros y pistas.
export function coinWalletBalance(
  earned: number,
  introCoinsSpent: number,
  hintCoinsSpent = 0,
  welcome = 0,
): number {
  return Math.max(
    0,
    earned + welcome - introCoinsSpent - hintCoinsSpent,
  );
}

function playerSeed(value: string): number {
  let seed = 2166136261;
  for (let index = 0; index < value.length; index++) {
    seed = Math.imul(seed ^ value.charCodeAt(index), 16777619);
  }
  return seed >>> 0;
}

function shuffleForPlayer<T>(items: readonly T[], seed: string): T[] {
  const shuffled = [...items];
  let state = playerSeed(seed);
  for (let index = shuffled.length - 1; index > 0; index--) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    const other = Math.floor((state / 0x1_0000_0000) * (index + 1));
    [shuffled[index], shuffled[other]] = [shuffled[other], shuffled[index]];
  }
  return shuffled;
}

/// Reparte intros por jugador: 30 en su género y 15 restantes en Medley.
/// Los ids ya desbloqueados se conservan al ajustar la asignación existente.
export function assignIntrosByPlayer(
  ids: readonly string[],
  uid: string,
  genre: string,
  unlockedInGenre: readonly string[] = [],
  unlockedInMedley: readonly string[] = [],
) {
  const ordered = shuffleForPlayer(
    [...new Set(ids)],
    `${uid}:${genre}`,
  );
  const genreUnlocked = new Set(unlockedInGenre);
  const medleyUnlocked = new Set(
    ordered.filter((id) => unlockedInMedley.includes(`${genre}--${id}`)),
  );
  const personal = ordered.filter((id) => genreUnlocked.has(id));
  // En duplicados de progresos antiguos, el género conserva la intro.
  const medleyPinned = ordered.filter((id) =>
    !genreUnlocked.has(id) && medleyUnlocked.has(id)
  );
  const personalLimit = Math.max(
    personal.length,
    Math.min(introsPerGenre, ordered.length - medleyPinned.length),
  );
  personal.push(
    ...ordered
      .filter((id) => !genreUnlocked.has(id) && !medleyPinned.includes(id))
      .slice(0, personalLimit - personal.length),
  );

  const personalSet = new Set(personal);
  const medley = [...medleyPinned];
  const medleyLimit = Math.max(introsPerGenreInMedley, medley.length);
  medley.push(
    ...ordered
      .filter((id) => !personalSet.has(id) && !medleyUnlocked.has(id))
      .slice(0, medleyLimit - medley.length),
  );

  return { personal, medley };
}
