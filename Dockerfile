FROM cloakhq/cloakbrowser:latest

RUN pip install --no-cache-dir rs-trafilatura

# Suppress CloakBrowser's first-launch welcome banner
RUN mkdir -p /root/.cloakbrowser && touch /root/.cloakbrowser/.welcome_shown

COPY snitchmd.py /usr/local/bin/snitchmd
RUN chmod +x /usr/local/bin/snitchmd

ENTRYPOINT ["/entrypoint.sh", "snitchmd"]
CMD ["--help"]
