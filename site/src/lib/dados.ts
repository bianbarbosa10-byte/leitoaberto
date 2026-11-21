// Dados da camada GOLD exportados por `python -m pipeline.export_site`.
// Regra de ouro: taxas sao recalculadas somando numerador e denominador (nunca media de taxas).
import meta from "../data/meta.json";
import calendario from "../data/calendario.json";
import e1EsMes from "../data/e1_es_mes.json";
import e1HospAno from "../data/e1_hospital_ano.json";
import e1Perfil from "../data/e1_perfil_ano.json";
import e2Regiao from "../data/e2_regiao_ano.json";
import e2Mun from "../data/e2_municipio_ano.json";
import e2FluxoReg from "../data/e2_fluxo_regiao_ano.json";
import e2FluxoMun from "../data/e2_fluxo_municipio_ano.json";
import e2Perfil from "../data/e2_evasao_perfil_ano.json";
import e2Proc from "../data/e2_procedimento_ano.json";
import e2Mensal from "../data/e2_evasao_mensal.json";
import e3LeitosReg from "../data/e3_leitos_regiao_mes.json";
import e3LeitosMun from "../data/e3_leitos_municipio.json";
import e3Tipo from "../data/e3_leitos_tipo.json";
import e3Equip from "../data/e3_equipamentos_regiao.json";
import e3Serv from "../data/e3_servicos_regiao.json";

export const M = (meta as any[])[0];
export const CAL = calendario as any[];
export const E1_MES = e1EsMes as any[];
export const E1_HOSP = e1HospAno as any[];
export const E1_PERFIL = e1Perfil as any[];
export const E2_REG = e2Regiao as any[];
export const E2_MUN = e2Mun as any[];
export const E2_FLUXO_REG = e2FluxoReg as any[];
export const E2_FLUXO_MUN = e2FluxoMun as any[];
export const E2_PERFIL = e2Perfil as any[];
export const E2_PROC = e2Proc as any[];
export const E2_MENSAL = e2Mensal as any[];
export const E3_REG = e3LeitosReg as any[];
export const E3_MUN = e3LeitosMun as any[];
export const E3_TIPO = e3Tipo as any[];
export const E3_EQUIP = e3Equip as any[];
export const E3_SERV = e3Serv as any[];

// cor fixa por regiao (slot da paleta categorica) - a cor segue a entidade, nunca a posicao
export const REGIOES = ["Central", "Metropolitana", "Norte", "Sul"];
export const slotRegiao = (r: string) => Math.max(0, REGIOES.indexOf(r));

export const soma = (xs: any[], k: string) => xs.reduce((a, r) => a + (Number(r[k]) || 0), 0);
export const razao = (a: number, b: number) => (b ? a / b : null);

/** anos presentes no calendario, com quantos meses e se ha mes preliminar */
export const ANOS = [...new Set(CAL.map((c) => c.ano))].sort().map((ano) => {
  const meses = CAL.filter((c) => c.ano === ano);
  return { ano: String(ano), meses: meses.length, preliminar: meses.some((m) => m.status_dados !== "Consolidado") };
});
/** ano padrao dos filtros: o ultimo ano com 12 meses consolidados */
export const ANO_PADRAO = ([...ANOS].reverse().find((a) => a.meses === 12 && !a.preliminar) ?? ANOS[ANOS.length - 1]).ano;
export const rotuloAno = (a: (typeof ANOS)[number]) =>
  a.meses < 12 ? `${a.ano} (parcial: ${a.meses} meses${a.preliminar ? ", com meses preliminares" : ""})` : a.preliminar ? `${a.ano} (com meses preliminares)` : a.ano;

export const ULT_CNES = M.ultima_competencia_cnes as string;

/** meses exibidos nas series do SIH: corta os muito incompletos (< 90% das AIH esperadas ja processadas),
 *  que dariam uma "queda" falsa no fim da serie. Entre 90% e 99% o mes aparece marcado como preliminar. */
export const COMPLETUDE_MIN = 0.9;
const completude = Object.fromEntries(CAL.map((c) => [c.competencia, c.completude_sih]));
export const E1_MES_SERIE = E1_MES.filter((r) => (completude[r.competencia] ?? 0) >= COMPLETUDE_MIN);
export const MESES_OCULTOS = E1_MES.length - E1_MES_SERIE.length;
