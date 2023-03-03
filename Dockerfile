##
## Install FE dependencies ##
##
FROM node:19.4.0 AS npm
WORKDIR /opt
COPY package.json yarn.lock package-lock.json ./
RUN npm install

##
## BUILD BE ##
##
FROM clojure:temurin-19-tools-deps-1.11.1.1208 AS builder

WORKDIR /opt

COPY . .

COPY --from=npm /opt/node_modules node_modules
# Pre-download deps so they will be cached even if build fails and must be re-run
RUN clojure -A:cljs -Spath
#RUN env TIMBRE_LEVEL=:warn clojure -M:shadow-cljs release main
RUN env TIMBRE_LEVEL=:info clojure -M:shadow-cljs release main

# Pre-download deps so they will be cached even if build fails and must be re-run
RUN clojure -Spath
# Note: With AOC, the build below takes 10 min when run directly on my PC 🥶
RUN clojure -Sdeps '{:mvn/local-repo "./.m2/repository"}' -T:build uber

##
## RUNTIME IMAGE ##
##
FROM eclipse-temurin:19 AS runtime
COPY --from=builder /opt/target/app-0.0.1-standalone.jar /app.jar

EXPOSE 8009

# NOTE: The VM only has 256MB mem (and OS needs some too)
# NOTE: Could use `java -jar` as long as we do AOT
ENTRYPOINT ["java", "-Xms140m", "-Xmx200m", "-Dclojure.main.report=stderr", "-cp", "app.jar", "clojure.main", "-m", "com.example.server.server"]

# java -Dclojure.main.report=stderr -cp target/app-0.0.1-standalone.jar clojure.main -m com.example.server.server