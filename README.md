# ZOE

**ZOE** è l'assistente desktop che vive in una barra in cima allo schermo.

- `index.html`: la landing page (questa pagina)
- `app/`: l'app desktop in Electron (prototipo). Vedi [app/README.md](app/README.md)

## Landing page

È una sola pagina statica (`index.html`), senza build: si apre direttamente nel browser e si pubblica su GitHub Pages.

## Cosa contiene

- Banner con prezzo di lancio e conto alla rovescia verso una data reale
- Hero con la mascotte animata (gli occhi seguono il mouse, cliccala)
- Demo interattiva della barra in alto: widget, acqua, musica, una mosca da inseguire, e si addormenta se la lasci stare
- Chat dimostrativa con 12 comandi d'esempio (genera anche una password vera)
- Funzioni, novità, privacy, installazione, requisiti, prezzo e domande frequenti
- Personalizzazione dal vivo: 13 espressioni, 8 colori, 5 tipi di occhi, 11 accessori, nome (salvati nel browser)

## Da personalizzare

In fondo a `index.html` c'è l'oggetto `CONFIG`:

```js
const CONFIG = {
  price: '€ 19,90',
  oldPrice: '€ 39,90',
  version: '1.0.0',
  buyUrl: '#',                       // link di pagamento (es. Stripe Payment Link)
  offerEnds: '2026-12-31T23:59:59',  // fine del prezzo di lancio
  contact: { label: '@zoe.assistente', url: 'https://instagram.com/' }
};
```

## Pubblicare su GitHub Pages

Settings → Pages → Source: *Deploy from a branch* → branch `main`, cartella `/ (root)`.
