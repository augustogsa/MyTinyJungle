package api

import (
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

// Multilingual matching. Every knowledge entry and doc is also indexed with its translations from the content
// locale tables (pt-BR, es, fr, de, ja), so a question in any of those languages matches the same entries an
// English one would. Latin scripts are folded (accents off, lower case, light plural stemming); Japanese is
// cut into kanji/katakana runs (whole run plus bigrams), since particles in hiragana carry no meaning here.

var mlLangs = []string{"pt-BR", "es", "fr", "de", "ja"}

var mlStop = func() map[string]bool {
	m := map[string]bool{}
	for _, w := range strings.Fields(`
		que por porque para pra pro com sem uma umas uns dos das nas nos num numa esta este isso essa esse minha meu minhas meus sua seu tem tao estao esta ficando fica como quando onde qual muito mais menos ser sao foi vai faz fazer eu voce ela ele elas eles mim tambem ainda dia vez vezes quanto quantos quanta tempo frequencia sempre agora
		planta plantas folha folhas vaso
		las los del una unos unas por porque para con sin esta este estan mis tus sus muy mas cuando donde como cual cada hay son ser puedo debo hace que cuanto cuantas cuantos tiempo frecuencia siempre ahora
		hoja hojas maceta
		les des une est sont pour par avec sans dans sur mon mes ses ton tes leur leurs tres plus quand comment pourquoi quelle quel faut faire elle elles ils qui que cette ces etre ont combien souvent temps toujours
		feuille feuilles plante plantes pot
		der die das den dem des ein eine einen einem einer und oder mit ohne fur auf ist sind wie wann warum was ich mein meine meiner meinen sehr mehr nicht kein keine sollte soll kann wird werden zum zur von bei aus oft haufig immer jetzt
		blatt blatter pflanze pflanzen topf`) {
		m[w] = true
	}
	return m
}()

func fold(s string) string {
	var b strings.Builder
	for _, r := range norm.NFD.String(strings.ToLower(s)) {
		if unicode.Is(unicode.Mn, r) {
			continue
		}
		if r == 'ß' {
			b.WriteString("ss")
			continue
		}
		b.WriteRune(r)
	}
	return norm.NFC.String(b.String())
}

func isCJK(r rune) bool {
	return unicode.Is(unicode.Han, r) || unicode.Is(unicode.Katakana, r) || r == 'ー'
}

func mlStem(w string) string {
	for _, suf := range []string{"mente", "ando", "endo", "ions", "ar", "er", "ir", "es", "en", "s", "x", "e", "a", "o"} {
		if len(w) > len(suf)+3 && strings.HasSuffix(w, suf) {
			return w[:len(w)-len(suf)]
		}
	}
	return w
}

// mlWords tokenizes text in any of our languages.
func mlWords(s string) []string {
	var out []string
	var run []rune
	flush := func() {
		defer func() { run = run[:0] }()
		if len(run) == 0 {
			return
		}
		if isCJK(run[0]) {
			out = append(out, string(run))
			for i := 0; i+1 < len(run) && len(run) > 2; i++ {
				out = append(out, string(run[i:i+2]))
			}
			return
		}
		w := string(run)
		if len(run) > 2 && !mlStop[w] && !stop[w] {
			out = append(out, mlStem(w))
		}
	}
	for _, r := range fold(s) {
		switch {
		case isCJK(r):
			if len(run) > 0 && !isCJK(run[0]) {
				flush()
			}
			run = append(run, r)
		case unicode.IsLetter(r) && !unicode.Is(unicode.Hiragana, r):
			if len(run) > 0 && isCJK(run[0]) {
				flush()
			}
			run = append(run, r)
		default:
			flush()
		}
	}
	flush()
	return out
}

// mlIndex is a per-language weighted bag of words.
type mlIndex map[string]map[string]float64

func (m mlIndex) add(lang, text string, w float64) {
	if text == "" {
		return
	}
	if m[lang] == nil {
		m[lang] = map[string]float64{}
	}
	for _, t := range mlWords(text) {
		m[lang][t] += w
	}
}

// trLocked translates with the locale tables already held by the caller (b.mu held or during load).
func trWith(locales map[string]map[string]string, lang, s string) string {
	if t, ok := locales[lang][s]; ok && t != "" {
		return t
	}
	return ""
}
