FROM eclipse-temurin:21-jre-noble

RUN apt-get update \
    && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-rus tesseract-ocr-eng wget \
    && libdir="/usr/lib/$(uname -m)-linux-gnu" \
    && ln -s "$libdir/liblept.so.5" "$libdir/libleptonica.so" \
    && ln -s "$libdir/libtesseract.so.5" "$libdir/libtesseract.so" \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /app app

WORKDIR /app
COPY build/libs/norma-ryadom-server.jar app.jar
USER app

ENV TESSDATA_PATH=/usr/share/tesseract-ocr/5/tessdata
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=5 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/actuator/health/liveness || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
