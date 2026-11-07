import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { LimiteTasa } from "./rate_limit.ts";

Deno.test("bloquea al pasar el maximo y libera al deslizar la ventana", () => {
  const limite = new LimiteTasa(3, 60_000);
  assertEquals(limite.consumir("a", 1), 0);
  assertEquals(limite.consumir("a", 10_000), 0);
  assertEquals(limite.consumir("a", 20_000), 0);
  assertEquals(limite.consumir("a", 30_000), 31); // el primero sale en ~60 s
  assertEquals(limite.consumir("b", 30_000), 0); // otro uid no se ve afectado
  assertEquals(limite.consumir("a", 60_002), 0);
});

Deno.test("limpia entradas viejas", () => {
  const limite = new LimiteTasa(5, 1_000);
  for (let i = 0; i < 50; i++) limite.consumir(`u${i}`, 1_000);
  assertEquals(limite.tamano, 50);
  limite.consumir("nuevo", 5_000);
  assertEquals(limite.tamano, 1);
});
