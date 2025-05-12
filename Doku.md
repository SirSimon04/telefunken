# Telefunken - Online-Kartenspiel

## Leute
- Jeremie Bents
- Simon Engel

## Anforderungen

### Deliverables:
- Auf Webserver
- Spiel starten
- Bis zu 4 Personen können beitreten
- 108 Karten, erste zwei Runden können gespielt werden.
- Server verwaltet Zufall

### Out of scope
- Karten splitten.

### Spielprinzip (vorher definierte Anforderungen)
- Kartenspiel soll spielbar sein (erstmal ein fixes Regelwerk, auch wenn es mehrere Varianten des Spiels gibt)
- Liste von Hostings soll verfügbar sein
- Man kann entweder ein Spiel Hosten:
   * Anzahl Spieler auswählen
   * Namen eingeben
   * Passwort festlegen
- Oder ein gehostetes Spiel joinen:
   * Mittels eines Passwortes soll man dann dem jeweiligen Spiel joinen können
   * Nach dem Spiel kann man entweder verlassen oder neustarten klicken

Details:
- Techstack ist Flame (auf Flutter basiert) 
- zur Datenspeicherung wird Firebase verwendet

Spielablauf:
- Zwei 52er Kartensets inklusive der jeweils 2 Joker werden gemischt. => Insgesamt 108 Karten.
- Der nächste Spieler in der Reihe muss die Karten so splitten, dass jeder 11 Karten besitzt und der der splittet 12. Formel (n für Anzahl der Spieler) = n * 11 +1
- Wenn er richtig splittet gewinnt er einen "Coin" dazu
- Spieler 1 teilt die Karten aus
- Spieler 2 ist an der Reihe (da er 12 Karten hat) und kann entweder legen oder muss ablegen (siehe unten)
- Nächster Spieler ist dran..
- Zu Beginn muss immer eine Karte gezogen werden.
- Zum Ende des Spielzuges muss immer eine Karte abgelegt werden.
- Joker, die auf dem Tisch liegen dürfen durch die fehlende Zahl ersetzt werden und wiederverwendet werden.

Kaufen aka. Stealen:
- Wenn einem die Karte gefällt, die ein Spielender abgelegt hat, dann darf man sie kaufen. Das muss jedoch geschehen, bevor der nächste Spieler eine Karte zieht.
- Wenn Spieler 1 abgelegt hat und Spieler 4 kaufen möchte, dann haben Spieler 2 und 3 "Vorrecht" diese Karte zu kaufen wenn sie möchten.
- Wird gekauft, so verfällt ein "Coin" des Spielenden (Jeder hat zu Beginn 7 Coins. Nur durch richtig splitten kann ein Coin dazugewonnen werde)

Wann darf abgelegt werden: Es gibt 7 Runden.
1. zwei 3er Paare
2. ein 4er Paar
3. zwei 4er Paare
4. ein 5er Paar
5. zwei 5er Paare
6. ein 6er Paar
7. eine 7er Reihe

Nutzung von Jokern:
- Joker sind die Karten -> 2 & Joker 
- Man darf immer nur weniger Joker spielen als die Anzahl an richtig gelegten Karten. 
- Ausnahme: man kann die 2 auch als Zahl spielen. -> 2, 2, 2 dann darf man auch 2, 2, J legen. Oder die Reihe: 2, 3, J, 5, J, J, 8
- Ablegen: Nach jedem Spielzug muss eine Karte abgelegt werden. Man darf also nicht mit legen das Spiel beenden.
- Punkteverteilung: Karten 3 - 7: 05 Punkte Karten 8 - K: 10 Punkte Karten Ass : 15 Punkte Karten 2 : 25 Punkte Karten Joker: 50 Punkte

## Ausführung
Es werden 3 Möglichkeiten zur Betrachtung des entwickelten Spiels bereitgestellt. Es kann das Video betrachtet werden, online direkt gespielt oder lokal mit Podman (Docker-Alternative) gestartet werden.

### Video
- TODO: Insert Link to Video here

### Online Access
Das Spiel ist online [hier](https://telefunken.simon-engel.com/) zu finden.

### Podman usage
- only tested with podman, but docker should work as well
- Podman version: 5.4.2
- `podman build -t telefunken .` to build the image
- `podman run -i -p 8080:9000 -td localhost/telefunken:latest`
- das Spiel ist dann lokal unter [localhost:8080](localhost:8080) zu finden

## Metriken

*Gemeinsam geschätzte Note*: 1.0

*Erreichte Ziele*:
- alle funktionalen Anforderungen wurden erfüllt
- Notiz: Der Scope des Projektes war deutlich zu groß gewählt. Die Anforderungen waren nur unter enormen Aufwand umsetzbar. 

*Besonders gut*:
Die lokale Ausführung und das einfache Deployment sind in diesem Projekt besonders gut gelungen. Die drei Möglichkeiten liefern verschiedene, einfache Wege. Auch ist das Spiel schon im Internet verfügbar und kann so ohne Aufwand ausprobiert werden. Die lokale Ausführung kann durch die Verwendung von Containern mit Podman realisiert werden.
