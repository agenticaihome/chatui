# Spanish glossary

`app_en.arb` holds the English texts and is the template; `app_es.arb` holds
the Spanish ones, under the same keys. `flutter gen-l10n` (or `flutter pub
get`) writes `app_localizations*.dart` from them. `test/l10n_test.dart` fails
when a key is missing in either file, a placeholder differs, or a Spanish text
is the English one copied over.

Style: neutral Spanish for Spain and Latin America, "tú" form, short and plain
like the English. Imperatives: "Escribe" (not "Introduce" or "Ingresa"),
"Toca", "Elige", "Comprueba". Sentence case as in English. No Spain-only words
("teléfono", not "móvil"). Never "usted". The app also runs on desktops: for the
machine the app runs on, say "this device" / "este dispositivo", not "this phone".

| English | Spanish |
|---|---|
| wallet | billetera |
| watched address / account | dirección / cuenta observada |
| watch / stop watching | observar / dejar de observar |
| watch-only | solo lectura |
| address book | libreta de direcciones |
| balance | saldo |
| amount | cantidad |
| fee / miner fee | comisión / comisión de minería |
| send / receive | enviar / recibir |
| broadcast | difundir |
| sign / signing device | firmar / dispositivo firmante |
| cold signing | firma en frío |
| pending / confirmed | pendiente / confirmada |
| box | caja |
| UTXO, token, NFT | UTXO, token, NFT |
| coin control | control de monedas |
| consolidate / split | consolidar / dividir |
| dust | polvo |
| storage rent | alquiler de almacenamiento |
| asset | activo |
| issue / burn (a token) | emitir / quemar |
| recovery phrase | frase de recuperación |
| unlock / lock | desbloquear / bloquear |
| sync / synced | sincronizar / sincronizada |
| node | nodo |
| this device (a phone or a computer) | este dispositivo |
| objective (of the catalog) | objetivo |
| service | servicio |
| attachment / file (of a message) | adjunto / archivo |
| photo | foto |
| deposit | depósito |
| tunnel | túnel |
| peer / peer ID | par / ID de par |
| advertisement (of a node) | anuncio |
| rate / quote / credit | tarifa / cotización / crédito |
| ID | ID |
| settings | Ajustes |
| preview | vista previa |
| offline | sin conexión |

Never translated: addresses, IDs, hashes, token names and tickers, URLs, unit
symbols (ERG, MU, KiB), protocol and product names (ErgoPay, EIP-12, Rosen
Bridge, Celaut). Amounts keep one format in both languages: a point for
decimals and commas for thousands, as Ergo wallets and explorers show them and
as the amount fields read them.
