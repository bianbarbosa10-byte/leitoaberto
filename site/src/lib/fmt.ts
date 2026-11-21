const nf = (d: number) => new Intl.NumberFormat("pt-BR", { minimumFractionDigits: d, maximumFractionDigits: d });

export const int = (v: number | null | undefined) => (v == null || isNaN(v) ? "–" : nf(0).format(v));
export const dec = (v: number | null | undefined, d = 1) => (v == null || isNaN(v) ? "–" : nf(d).format(v));
export const pct = (v: number | null | undefined, d = 1) => (v == null || isNaN(v) ? "–" : nf(d).format(v * 100) + "%");
export const brl = (v: number | null | undefined) =>
  v == null ? "–" : new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: 0 }).format(v);
export const div = (a: number, b: number) => (b ? a / b : null);

const MESES = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];
export const mesAno = (comp: string) => `${MESES[+comp.slice(5, 7) - 1]}/${comp.slice(2, 4)}`;
export const dataHora = (iso: string) => {
  const d = new Date(iso);
  return isNaN(+d) ? iso : d.toLocaleDateString("pt-BR", { day: "2-digit", month: "short", year: "numeric" });
};
