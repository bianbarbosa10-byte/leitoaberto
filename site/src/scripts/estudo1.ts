// Estudo 1 com filtros no navegador: ano, mes e estabelecimento.
// Dados em /data/e1 (gerados por pipeline/export_site.py): indice.json, todos.json e h/<cnes>.json.
// Regra: taxas sempre somam numerador e denominador do recorte antes de dividir.
import { registrarGrafico, redesenharGraficos, ordenavel, type Spec } from "./app";
import { int, dec, pct, brl, mesAno } from "../lib/fmt";

type Col = Record<string, any[]>;
interface Indice { meses: Col; hospitais: Col; procedimentos: Col }
interface Pacote { perfil: Col; proc: Col; hosp_mes?: Col }

const base = document.body.dataset.base || "";
const pagina = document.querySelector<HTMLElement>("[data-e1]")?.dataset.e1 as "unidades" | "procedimentos" | undefined;

const linhas = (c: Col) => {
  const ks = Object.keys(c), n = c[ks[0]]?.length ?? 0, out: any[] = [];
  for (let i = 0; i < n; i++) { const o: any = {}; for (const k of ks) o[k] = c[k][i]; out.push(o); }
  return out;
};
const soma = (xs: any[], k: string) => xs.reduce((a, r) => a + (+r[k] || 0), 0);
const razao = (a: number, b: number) => (b ? a / b : null);
const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (s: any) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);

let IDX: Indice, TODOS: Pacote;
let MESES: { competencia: string; status_dados: string; completude_sih: number }[] = [];
let HOSP: Record<string, any> = {};
let PROC: Record<string, any> = {};
const cacheHosp: Record<string, Pacote> = {};
const estado = { ano: "", mes: "", cnes: "" };

async function json(url: string) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.json();
}
async function pacote(cnes: string): Promise<Pacote> {
  if (!cnes) return TODOS;
  cacheHosp[cnes] ??= await json(`${base}/data/e1/h/${cnes}.json`);
  return cacheHosp[cnes];
}

// ---------------------------------------------------------------- filtros
function anoPadrao() {
  const anos = [...new Set(MESES.map((m) => m.competencia.slice(0, 4)))].sort();
  const completo = [...anos].reverse().find((a) => {
    const ms = MESES.filter((m) => m.competencia.startsWith(a));
    return ms.length === 12 && ms.every((m) => m.status_dados === "Consolidado");
  });
  return completo ?? anos[anos.length - 1];
}
function competenciasSelecionadas() {
  return MESES.map((m) => m.competencia).filter((c) => c.startsWith(estado.ano) && (!estado.mes || c.slice(5, 7) === estado.mes));
}
function lerUrl() {
  const q = new URLSearchParams(location.search);
  const anos = new Set(MESES.map((m) => m.competencia.slice(0, 4)));
  estado.ano = anos.has(q.get("ano") ?? "") ? q.get("ano")! : anoPadrao();
  estado.mes = /^\d\d$/.test(q.get("mes") ?? "") ? q.get("mes")! : "";
  estado.cnes = HOSP[q.get("cnes") ?? ""] ? q.get("cnes")! : "";
}
function gravarUrl() {
  const q = new URLSearchParams();
  q.set("ano", estado.ano);
  if (estado.mes) q.set("mes", estado.mes);
  if (estado.cnes) q.set("cnes", estado.cnes);
  history.replaceState(null, "", `${location.pathname}?${q}`);
  // as abas levam os mesmos filtros
  document.querySelectorAll<HTMLAnchorElement>("[data-aba]").forEach((a) => { a.search = `?${q}`; });
}
function montarFiltros() {
  const selAno = $<HTMLSelectElement>("f-ano"), selMes = $<HTMLSelectElement>("f-mes"), selHosp = $<HTMLSelectElement>("f-hosp");
  const anos = [...new Set(MESES.map((m) => m.competencia.slice(0, 4)))].sort().reverse();
  selAno.innerHTML = anos.map((a) => `<option value="${a}">${a}</option>`).join("");
  selHosp.innerHTML = `<option value="">Todos os estabelecimentos</option>` +
    linhas(IDX.hospitais).map((h) => `<option value="${esc(h.cnes)}">${esc(h.hospital)} · ${esc(h.municipio)}</option>`).join("");
  const preencherMeses = () => {
    const ms = MESES.filter((m) => m.competencia.startsWith(estado.ano));
    selMes.innerHTML = `<option value="">Todos os meses</option>` + ms.map((m) =>
      `<option value="${m.competencia.slice(5, 7)}">${mesAno(m.competencia)}${m.status_dados !== "Consolidado" ? " (preliminar)" : ""}</option>`).join("");
    if (estado.mes && !ms.some((m) => m.competencia.slice(5, 7) === estado.mes)) estado.mes = "";
    selMes.value = estado.mes;
  };
  selAno.value = estado.ano; preencherMeses(); selHosp.value = estado.cnes;
  selAno.onchange = () => { estado.ano = selAno.value; preencherMeses(); atualizar(); };
  selMes.onchange = () => { estado.mes = selMes.value; atualizar(); };
  selHosp.onchange = () => { estado.cnes = selHosp.value; atualizar(); };
  $("f-limpar").onclick = () => { estado.ano = anoPadrao(); estado.mes = ""; estado.cnes = ""; selAno.value = estado.ano; preencherMeses(); selHosp.value = ""; atualizar(); };
}
function rotuloRecorte() {
  const periodo = estado.mes ? mesAno(`${estado.ano}-${estado.mes}`) : estado.ano;
  const quem = estado.cnes ? HOSP[estado.cnes].hospital : "todos os hospitais do ES";
  return `${periodo} · ${quem}`;
}
function avisoPreliminar(comps: string[]) {
  const prel = MESES.filter((m) => comps.includes(m.competencia) && m.status_dados !== "Consolidado");
  const el = $("f-aviso");
  el.hidden = !prel.length;
  el.textContent = prel.length ? `Inclui ${prel.length} ${prel.length === 1 ? "mês preliminar" : "meses preliminares"}: o SIH ainda está recebendo AIH desse período` : "";
}
function kpi(id: string, valor: string, nota: string) {
  $(id).querySelector(".value")!.textContent = valor;
  $(id).querySelector(".note")!.textContent = nota;
}

// ---------------------------------------------------------------- UNIDADES
let specOcup: Spec, specPerfil: Spec, specSerie: Spec;

async function unidades() {
  const comps = competenciasSelecionadas();
  const hm = linhas(TODOS.hosp_mes!);
  const sel = hm.filter((r) => comps.includes(r.competencia) && (!estado.cnes || r.cnes === estado.cnes));
  const saidas = soma(sel, "saidas");
  kpi("k-ocup", pct(razao(soma(sel, "pacientes_dia"), soma(sel, "leitos_dia"))), "Referência usual: 75% a 85%");
  kpi("k-perm", `${dec(razao(soma(sel, "pacientes_dia_competencia"), saidas))} dias`, `${int(saidas)} saídas`);
  kpi("k-giro", dec(razao(saidas, soma(sel, "leitos_sus_operacionais"))), "Saídas por leito SUS operacional por mês");
  kpi("k-mort", pct(razao(soma(sel, "obitos_48h_mais"), saidas), 2), `Valor aprovado em AIH: ${brl(soma(sel, "valor_total_aih"))}`);

  // grafico A: ranking (todos) ou serie mensal do hospital x ES (um hospital)
  if (!estado.cnes) {
    const porH: Record<string, any> = {};
    for (const r of sel) {
      const h = (porH[r.cnes] ??= { cnes: r.cnes, pd: 0, ld: 0, s: 0, lo: 0, n: 0 });
      h.pd += r.pacientes_dia; h.ld += r.leitos_dia; h.s += r.saidas; h.lo += r.leitos_sus_operacionais; h.n++;
    }
    const top = Object.values(porH).filter((h: any) => h.lo / h.n >= 10).sort((a: any, b: any) => b.s - a.s).slice(0, 20);
    $("g1-titulo").textContent = "Ocupação dos 20 hospitais com mais saídas";
    $("g1-sub").textContent = "Hospitais com 10 ou mais leitos SUS operacionais. Linha tracejada = 85%.";
    specOcup = { kind: "bar", unit: "pct", horizontal: true, ref: { value: 0.85, label: "85%" },
      x: top.map((h: any) => HOSP[h.cnes]?.hospital ?? h.cnes), series: [{ name: "Taxa de ocupação", data: top.map((h: any) => razao(h.pd, h.ld)) }] };
  } else {
    const ms = MESES.filter((m) => m.competencia.startsWith(estado.ano)).map((m) => m.competencia);
    const taxa = (rs: any[]) => razao(soma(rs, "pacientes_dia"), soma(rs, "leitos_dia"));
    $("g1-titulo").textContent = `Ocupação mês a mês em ${estado.ano}`;
    $("g1-sub").textContent = "O hospital escolhido comparado à média do ES. Linha tracejada = 85%.";
    specOcup = { kind: "line", unit: "pct", min0: false, ref: { value: 0.85, label: "85%" }, x: ms.map(mesAno), series: [
      { name: HOSP[estado.cnes].hospital.slice(0, 28), slot: 0, data: ms.map((c) => taxa(hm.filter((r) => r.cnes === estado.cnes && r.competencia === c))) },
      { name: "Média do ES", slot: 1, data: ms.map((c) => taxa(hm.filter((r) => r.competencia === c))) },
    ] };
  }

  // grafico B: permanencia por faixa etaria e carater
  const pac = await pacote(estado.cnes);
  const perfil = linhas(pac.perfil).filter((r) => comps.includes(r.competencia));
  const faixas = [...new Set(perfil.map((r) => r.faixa_etaria))].sort();
  specPerfil = { kind: "bar", unit: "dec1", x: faixas.map((f) => f.slice(3)), series: ["Eletivo", "Urgência"].map((c, i) => ({
    name: c, slot: i, data: faixas.map((f) => { const rs = perfil.filter((r) => r.faixa_etaria === f && r.carater === c); return razao(soma(rs, "pacientes_dia"), soma(rs, "saidas")); }),
  })) };

  // grafico C: permanencia mes a mes (historico completo, sem meses muito incompletos)
  const serieMeses = MESES.filter((m) => m.completude_sih >= 0.9);
  const doRecorte = estado.cnes ? hm.filter((r) => r.cnes === estado.cnes) : hm;
  specSerie = { kind: "line", unit: "dec1", min0: false, x: serieMeses.map((m) => mesAno(m.competencia)),
    series: [{ name: "Média de permanência (dias)", data: serieMeses.map((m) => { const rs = doRecorte.filter((r) => r.competencia === m.competencia); return razao(soma(rs, "pacientes_dia_competencia"), soma(rs, "saidas")); }) }],
    preliminarDesde: serieMeses.findIndex((m) => m.status_dados !== "Consolidado") };
  $("g3-titulo").textContent = `Permanência média mês a mês · ${estado.cnes ? HOSP[estado.cnes].hospital : "ES"}`;

  // tabela: hospitais do recorte (todos) ou meses do hospital
  const tb = $<HTMLTableElement>("tabela");
  if (!estado.cnes) {
    $("t-titulo").textContent = "Indicadores por hospital";
    const porH: Record<string, any> = {};
    for (const r of sel) {
      const h = (porH[r.cnes] ??= { cnes: r.cnes, pd: 0, ld: 0, s: 0, lo: 0, n: 0, pdc: 0, o48: 0, v: 0 });
      h.pd += r.pacientes_dia; h.ld += r.leitos_dia; h.s += r.saidas; h.lo += r.leitos_sus_operacionais; h.n++;
      h.pdc += r.pacientes_dia_competencia; h.o48 += r.obitos_48h_mais; h.v += r.valor_total_aih;
    }
    const hs = Object.values(porH).filter((h: any) => h.s > 0 || h.ld > 0).sort((a: any, b: any) => b.s - a.s);
    tb.innerHTML = `<thead><tr><th>Hospital</th><th>Município</th><th>Região</th><th>Natureza</th><th class="n">Leitos SUS</th><th class="n">Saídas</th>
      <th class="n">Ocupação</th><th class="n">Permanência</th><th class="n">Giro/mês</th><th class="n">Mort. ≥48h</th><th class="n">Valor aprovado</th></tr></thead><tbody>` +
      hs.map((h: any) => { const H = HOSP[h.cnes] ?? {}; const oc = razao(h.pd, h.ld), pe = razao(h.pdc, h.s), gi = razao(h.s, h.lo), mo = razao(h.o48, h.s);
        return `<tr><td><a href="?ano=${estado.ano}${estado.mes ? `&mes=${estado.mes}` : ""}&cnes=${esc(h.cnes)}" data-cnes="${esc(h.cnes)}">${esc(H.hospital ?? h.cnes)}</a></td><td>${esc(H.municipio)}</td><td>${esc(H.regiao_saude)}</td><td>${esc(H.grupo_natureza)}</td>
          <td class="n" data-v="${h.lo / h.n}">${dec(h.lo / h.n, 0)}</td><td class="n" data-v="${h.s}">${int(h.s)}</td><td class="n" data-v="${oc ?? -1}">${pct(oc)}</td>
          <td class="n" data-v="${pe ?? -1}">${dec(pe)}</td><td class="n" data-v="${gi ?? -1}">${dec(gi)}</td><td class="n" data-v="${mo ?? -1}">${pct(mo, 2)}</td><td class="n" data-v="${h.v}">${brl(h.v)}</td></tr>`; }).join("") + "</tbody>";
    tb.querySelectorAll<HTMLAnchorElement>("a[data-cnes]").forEach((a) => a.addEventListener("click", (e) => {
      e.preventDefault(); estado.cnes = a.dataset.cnes!; $<HTMLSelectElement>("f-hosp").value = estado.cnes; atualizar(); window.scrollTo({ top: 0, behavior: "smooth" });
    }));
  } else {
    $("t-titulo").textContent = `Mês a mês · ${HOSP[estado.cnes].hospital}`;
    const rs = sel.sort((a, b) => a.competencia.localeCompare(b.competencia));
    const st = Object.fromEntries(MESES.map((m) => [m.competencia, m.status_dados]));
    tb.innerHTML = `<thead><tr><th>Mês</th><th class="n">Leitos SUS</th><th class="n">Saídas</th><th class="n">Ocupação</th><th class="n">Permanência</th>
      <th class="n">Giro</th><th class="n">Mort. ≥48h</th><th class="n">Valor aprovado</th><th>Status</th></tr></thead><tbody>` +
      rs.map((r) => { const oc = razao(r.pacientes_dia, r.leitos_dia), pe = razao(r.pacientes_dia_competencia, r.saidas), gi = razao(r.saidas, r.leitos_sus_operacionais), mo = razao(r.obitos_48h_mais, r.saidas);
        return `<tr><td data-v="${r.competencia}">${mesAno(r.competencia)}</td><td class="n" data-v="${r.leitos_sus_operacionais}">${int(r.leitos_sus_operacionais)}</td><td class="n" data-v="${r.saidas}">${int(r.saidas)}</td>
          <td class="n" data-v="${oc ?? -1}">${pct(oc)}</td><td class="n" data-v="${pe ?? -1}">${dec(pe)}</td><td class="n" data-v="${gi ?? -1}">${dec(gi)}</td>
          <td class="n" data-v="${mo ?? -1}">${pct(mo, 2)}</td><td class="n" data-v="${r.valor_total_aih}">${brl(r.valor_total_aih)}</td><td>${esc(st[r.competencia])}</td></tr>`; }).join("") + "</tbody>";
  }
  delete tb.dataset.ordenada;
  tb.querySelectorAll("th").forEach((th) => delete (th as HTMLElement).dataset.sort);
  ordenavel(tb);
}

// ---------------------------------------------------------------- PROCEDIMENTOS
let specTop: Spec, specGrupo: Spec, specCpx: Spec;
let procAgregado: any[] = [];

async function procedimentos() {
  const comps = competenciasSelecionadas();
  const pac = await pacote(estado.cnes);
  const rs = linhas(pac.proc).filter((r) => comps.includes(r.competencia));
  const porP: Record<string, any> = {};
  for (const r of rs) {
    const p = (porP[r.proc_rea] ??= { proc_rea: r.proc_rea, aih: 0, saidas: 0, dias: 0, obitos: 0, valor: 0 });
    p.aih += r.aih; p.saidas += r.saidas; p.dias += r.dias; p.obitos += r.obitos; p.valor += r.valor;
  }
  procAgregado = Object.values(porP).sort((a: any, b: any) => b.aih - a.aih);
  const aih = soma(procAgregado, "aih"), valor = soma(procAgregado, "valor");
  kpi("k-aih", int(aih), `${int(soma(procAgregado, "saidas"))} saídas`);
  kpi("k-distintos", int(procAgregado.length), "Procedimentos SIGTAP diferentes");
  kpi("k-valor", brl(valor), "Soma do valor das AIH aprovadas");
  kpi("k-medio", brl(razao(valor, aih)), "Valor médio por AIH aprovada");

  const top = procAgregado.slice(0, 15);
  specTop = { kind: "bar", unit: "int", horizontal: true, x: top.map((p: any) => PROC[p.proc_rea]?.procedimento ?? p.proc_rea),
    series: [{ name: "AIH aprovadas", data: top.map((p: any) => p.aih) }] };

  const porG: Record<string, number> = {};
  for (const p of procAgregado) { const g = PROC[p.proc_rea]?.grupo ?? "Outros"; porG[g] = (porG[g] ?? 0) + p.aih; }
  const gs = Object.entries(porG).sort((a, b) => b[1] - a[1]);
  specGrupo = { kind: "bar", unit: "int", horizontal: true, x: gs.map((g) => g[0]), series: [{ name: "AIH aprovadas", slot: 0, data: gs.map((g) => g[1]) }] };

  const cpx = ["Média", "Alta"].map((c) => procAgregado.filter((p: any) => (PROC[p.proc_rea]?.complexidade ?? "Média") === c));
  specCpx = { kind: "bar", unit: "pct", x: ["Média complexidade", "Alta complexidade"], series: [
    { name: "% das AIH", slot: 0, data: cpx.map((xs) => razao(soma(xs, "aih"), aih)) },
    { name: "% do valor", slot: 1, data: cpx.map((xs) => razao(soma(xs, "valor"), valor)) },
  ] };
  desenharTabelaProc();
}

function desenharTabelaProc() {
  const termo = ($<HTMLInputElement>("busca").value || "").trim().toLowerCase();
  const filtrados = procAgregado.filter((p: any) => !termo || p.proc_rea.includes(termo) || (PROC[p.proc_rea]?.procedimento ?? "").toLowerCase().includes(termo));
  const LIM = 300;
  const tb = $<HTMLTableElement>("tabela");
  tb.innerHTML = `<thead><tr><th>Código</th><th>Procedimento</th><th>Grupo</th><th>Complexidade</th><th class="n">AIH</th><th class="n">Saídas</th>
    <th class="n">Permanência</th><th class="n">Óbitos</th><th class="n">Mortalidade</th><th class="n">Valor aprovado</th><th class="n">Valor médio</th></tr></thead><tbody>` +
    filtrados.slice(0, LIM).map((p: any) => { const P = PROC[p.proc_rea] ?? {}; const pe = razao(p.dias, p.saidas), mo = razao(p.obitos, p.saidas), vm = razao(p.valor, p.aih);
      return `<tr><td data-v="${esc(p.proc_rea)}"><code>${esc(p.proc_rea)}</code></td><td style="white-space:normal;min-width:260px">${esc(P.procedimento ?? "")}</td><td>${esc(((g) => g.charAt(0).toUpperCase() + g.slice(1))((P.grupo ?? "").replace("Procedimentos ", "")))}</td>
        <td>${esc(P.complexidade ?? "")}</td><td class="n" data-v="${p.aih}">${int(p.aih)}</td><td class="n" data-v="${p.saidas}">${int(p.saidas)}</td>
        <td class="n" data-v="${pe ?? -1}">${dec(pe)}</td><td class="n" data-v="${p.obitos}">${int(p.obitos)}</td><td class="n" data-v="${mo ?? -1}">${pct(mo, 1)}</td>
        <td class="n" data-v="${p.valor}">${brl(p.valor)}</td><td class="n" data-v="${vm ?? -1}">${brl(vm)}</td></tr>`; }).join("") + "</tbody>";
  $("t-info").textContent = filtrados.length > LIM ? `Mostrando os ${LIM} procedimentos com mais AIH de ${int(filtrados.length)} encontrados. Use a busca para achar os demais.`
    : `${int(filtrados.length)} procedimento${filtrados.length === 1 ? "" : "s"}.`;
  tb.querySelectorAll("th").forEach((th) => delete (th as HTMLElement).dataset.sort);
  ordenavel(tb);
}

// ---------------------------------------------------------------- ciclo
let graficosProntos = false;
async function atualizar() {
  gravarUrl();
  const comps = competenciasSelecionadas();
  avisoPreliminar(comps);
  $("recorte").textContent = rotuloRecorte();
  document.body.classList.add("carregando");
  try {
    if (pagina === "unidades") await unidades(); else await procedimentos();
  } finally { document.body.classList.remove("carregando"); }
  if (!graficosProntos) {
    graficosProntos = true;
    if (pagina === "unidades") {
      registrarGrafico($("g1"), () => specOcup);
      registrarGrafico($("g2"), () => specPerfil);
      registrarGrafico($("g3"), () => specSerie);
    } else {
      registrarGrafico($("g1"), () => specTop);
      registrarGrafico($("g2"), () => specGrupo);
      registrarGrafico($("g3"), () => specCpx);
    }
  } else redesenharGraficos();
}

async function iniciar() {
  if (!pagina) return;
  try {
    [IDX, TODOS] = await Promise.all([json(`${base}/data/e1/indice.json`), json(`${base}/data/e1/todos.json`)]);
  } catch (e) {
    $("recorte").textContent = "Não foi possível carregar os dados. Tente recarregar a página.";
    return;
  }
  MESES = linhas(IDX.meses);
  HOSP = Object.fromEntries(linhas(IDX.hospitais).map((h) => [h.cnes, h]));
  PROC = Object.fromEntries(linhas(IDX.procedimentos).map((p) => [p.proc_rea, p]));
  lerUrl();
  montarFiltros();
  if (pagina === "procedimentos") {
    let t: number | undefined;
    $<HTMLInputElement>("busca").addEventListener("input", () => { clearTimeout(t); t = window.setTimeout(desenharTabelaProc, 200); });
  }
  await atualizar();
}

iniciar();
