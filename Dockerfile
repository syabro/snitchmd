FROM cloakhq/cloakbrowser:latest

RUN pip install --no-cache-dir rs-trafilatura

COPY cloak2md.py /usr/local/bin/cloak2md
RUN chmod +x /usr/local/bin/cloak2md

ENTRYPOINT ["/entrypoint.sh", "cloak2md"]
CMD ["--help"]
