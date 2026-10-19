import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';

Future<void> mostrarInstrucciones(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const InstruccionesDialog(),
);

class InstruccionesDialog extends StatelessWidget {
  const InstruccionesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Pantalla completa sobre el fondo líquido; en tablets el contenido
    // queda centrado con un ancho máximo.
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: LiquidBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      children: [
                        Image.asset(
                          'lib/assets/images/logo/riff_logo.png',
                          height: 120,
                          semanticLabel: 'Riff',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¿Cómo funciona?',
                          style: text.bodyLarge?.copyWith(
                            color: context.paleta.tintaSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        children: [
                          _Paso(
                            numero: 1,
                            titulo: 'Dificultades',
                            icono: Icons.stairs_rounded,
                            children: [
                              const Text(
                                'El juego tiene 3 dificultades, en este orden:',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: const [
                                  _Etiqueta('Fácil'),
                                  Icon(Icons.chevron_right, size: 18),
                                  _Etiqueta('Media'),
                                  Icon(Icons.chevron_right, size: 18),
                                  _Etiqueta('Avanzada'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const _Vineta(
                                'Cada dificultad usa hasta 5 niveles publicados.',
                              ),
                              const _Vineta(
                                'Completa los 5 niveles de una dificultad para desbloquear la siguiente.',
                              ),
                            ],
                          ),
                          const _Paso(
                            numero: 2,
                            titulo: 'Los niveles',
                            icono: Icons.queue_music_rounded,
                            children: [
                              Text(
                                'Cada nivel tiene 4 instrumentos con fragmentos de 30 segundos:',
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _Etiqueta('🥁 Batería'),
                                  _Etiqueta('🪗 Acordeón'),
                                  _Etiqueta('🎸 Guitarra'),
                                  _Etiqueta('🎵 Bajo'),
                                ],
                              ),
                            ],
                          ),
                          _Paso(
                            numero: 3,
                            titulo: 'Compra y juega',
                            icono: Icons.paid_rounded,
                            children: [
                              const Text(
                                'Cada partida empieza con un presupuesto de:',
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(
                                      color: context.paleta.tinta,
                                    ),
                                  ),
                                  child: Text(
                                    '\$1.000.000',
                                    style: text.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const _Vineta('Compras 3 de los 4 instrumentos.'),
                              const _Vineta(
                                'Cada precio (\$300.000 o \$400.000) se asigna al comprar; las 3 compras suman el presupuesto completo.',
                              ),
                            ],
                          ),
                          const _Paso(
                            numero: 4,
                            titulo: 'Descubre la melodía',
                            icono: Icons.hearing_rounded,
                            children: [
                              Text(
                                'Cada partida esconde la melodía en un instrumento elegido al azar.',
                              ),
                              SizedBox(height: 8),
                              _Vineta(
                                'Al descubrirla se habilitan los demás instrumentos y la mezcla sin voz.',
                                icono: Icons.check_circle_rounded,
                              ),
                              _Vineta(
                                'Si adivinas la canción, escuchas la grabación original.',
                                icono: Icons.check_circle_rounded,
                              ),
                            ],
                          ),
                          const _Paso(
                            numero: 5,
                            titulo: 'Monedas y Adivina la intro',
                            icono: Icons.headphones_rounded,
                            children: [
                              Text(
                                'Cada nivel que ganas por primera vez te da monedas 🪙:',
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _Etiqueta('Fácil · 2'),
                                  _Etiqueta('Media · 3'),
                                  _Etiqueta('Avanzada · 4'),
                                ],
                              ),
                              SizedBox(height: 10),
                              _Vineta(
                                'Repetir un nivel ya ganado no da monedas.',
                              ),
                              _Vineta(
                                'En Adivina la intro, 1 moneda saca una carta con una intro al azar.',
                              ),
                              _Vineta(
                                'Escucha los primeros segundos y escribe la canción; si aciertas suena la original.',
                              ),
                              _Vineta(
                                'Tras 3 fallos seguidos debes esperar 30 segundos.',
                              ),
                              _Vineta(
                                'Las intros que ya tienes se pueden jugar sin conexión.',
                              ),
                            ],
                          ),
                          const _Paso(
                            numero: 6,
                            titulo: 'Desafía a tus amigos',
                            icono: Icons.groups_rounded,
                            children: [
                              Text(
                                'Juega en una sala de hasta 5 personas. Necesitas una cuenta registrada.',
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _Etiqueta('🥁 Adivina la canción · gratis'),
                                  _Etiqueta(
                                    '🎧 Intros · crear 🎟️ 10 · entrar 🎟️ 5',
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              _Vineta(
                                'Al crearla eliges el reto y si es pública o cerrada. Las canciones salen de todas las dificultades.',
                              ),
                              _Vineta(
                                'Únete con el código de 6 letras, escaneando el QR o desde Salas abiertas.',
                              ),
                              _Vineta(
                                'Cada jugador toca "¡Estoy listo!"; la partida empieza sola cuando todos (2 o más) están listos.',
                              ),
                              _Vineta(
                                'Todos juegan las mismas canciones; si sales en plena partida dejas de competir.',
                              ),
                            ],
                          ),
                          const _Paso(
                            numero: 7,
                            titulo: 'Retos de las salas',
                            icono: Icons.emoji_events_rounded,
                            children: [
                              _Vineta(
                                'Contrarreloj ⏱️: 10 minutos, desde que todos están listos, para adivinar todas las canciones que puedas. Cada acierto da 100 puntos, hasta 50 más por rapidez y 1 por cada \$10.000 sin gastar. Puedes saltar una canción sin puntos.',
                                icono: Icons.timer_outlined,
                              ),
                              _Vineta(
                                'Eliminación 🥊: sin tiempo. Cuando todos menos uno adivinan la canción, ese uno queda eliminado. Gana el último que queda.',
                                icono: Icons.person_remove_outlined,
                              ),
                            ],
                          ),
                          const _Paso(
                            numero: 8,
                            titulo: 'Fichas',
                            icono: Icons.confirmation_number_rounded,
                            children: [
                              Text(
                                'Las fichas 🎟️ son la moneda de las salas, distintas de las monedas 🪙.',
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _Etiqueta('🥇 10'),
                                  _Etiqueta('🥈 7'),
                                  _Etiqueta('🥉 3'),
                                ],
                              ),
                              SizedBox(height: 10),
                              _Vineta(
                                'Se ganan al terminar una sala de Adivina la canción, en los 3 primeros puestos.',
                              ),
                              _Vineta(
                                'No cobra quien abandonó ni quien no acertó ninguna canción.',
                              ),
                              _Vineta(
                                'Crear una sala de intros cuesta 10 y entrar a una cuesta 5; si sales antes de que empiece, te las devuelve.',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      children: [
                        Text(
                          '¡ESCUCHA · COMPRA · ADIVINA!',
                          textAlign: TextAlign.center,
                          style: text.titleSmall?.copyWith(letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: LiquidGlassButton(
                            onPressed: () => Navigator.of(context).pop(),
                            label: '¡A jugar!',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.icono,
    required this.children,
  });

  final int numero;
  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$numero',
              style: text.headlineLarge?.copyWith(
                color: AppColors.signalOrange,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo.toUpperCase(),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Icon(icono, color: context.paleta.tintaSuave),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DefaultTextStyle.merge(
                    style: text.bodyMedium,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: context.paleta.superficie,
      border: Border.all(color: context.paleta.borde),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: context.paleta.tinta,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Vineta extends StatelessWidget {
  const _Vineta(this.texto, {this.icono = Icons.circle});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            icono,
            size: icono == Icons.circle ? 8 : 16,
            color: context.paleta.tinta,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ],
    ),
  );
}
