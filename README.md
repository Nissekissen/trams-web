# Trams

En liten app för att hålla koll på spårvagnar och vilken modell de är av.
Samma uppbyggnad som middagsboken men utan inloggning.

## Tekniken

- **Sinatra** (Ruby webramverk, inget Rails)
- **ActiveRecord** för databasen, med vanliga migreringar i `db/migrate/`.
  `rake db:migrate` kör nya migreringar och skriver om `db/schema.rb` —
  ändra strukturen genom att lägga till en ny migrering, inte genom att
  redigera `schema.rb` direkt.
- **ERB**-mallar, ren CSS, ingen JavaScript-ramverk
- **SQLite** lokalt, **Postgres** i produktion (styrs av miljövariabeln
  `DATABASE_URL`)

## Komma igång lokalt

Du behöver Ruby 3.1 eller senare installerat.

```bash
bundle install
rake db:migrate
bundle exec rackup -p 4567
```

Öppna sedan `http://localhost:4567` i webbläsaren.

## Produktion (Postgres)

Sätt miljövariabeln `DATABASE_URL` till din Postgres-anslutning, t.ex.:

```bash
export DATABASE_URL="postgres://user:password@host:5432/trams"
export RACK_ENV=production
bundle install
rake db:migrate
bundle exec puma -p 4567
```

Så länge `DATABASE_URL` är satt används Postgres istället för SQLite — ingen
övrig kod behöver ändras.

## Struktur

```
app.rb                  Sinatra-appen: alla routes
config/environment.rb   Databaskoppling, laddar modeller
models/tram.rb           Spårvagn, hör till en modell
models/model.rb          Spårvagnsmodell (t.ex. "M32", "A36")
db/migrate/              Migreringar — varje strukturändring som en egen fil
db/schema.rb             Autogenererad ögonblicksbild (skriv inte i den direkt)
views/                   ERB-mallar, en mapp per resurs
public/css/style.css     Stilmall (samma profil som middagsboken, blå accent)
```

## Att tänka på

Appen saknar inloggning. Om den ska nås över internet och innehåller
känsligt innehåll, lägg ett lösenordsskydd framför den (t.ex. Basic Auth i
en reverse proxy, eller kopiera autentiseringsmönstret från middagsboken)
innan den exponeras.

## Databas setup

Antingen uppdatera WAVA resultat efter varje nytt resultat eller ett specifikt datum
Poängen ligger under resultat-tabellen
WAVA beräknare som hjälp-funktion. Tar in en tävling.
Vi behöver en tabell för WAVA åldersfaktorer
Hjälpfunktion för födelsedatum till ålder

Funktionnärsuppdrag

Börja utan permissions - alla kan lägga till tävlingar.
Skapa användaren från en färdig lista, skriva översättningsverktyg
När de loggar in första gången - välj lösenord
