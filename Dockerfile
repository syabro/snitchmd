FROM cloakhq/cloakbrowser:latest

RUN pip install --no-cache-dir rs-trafilatura

COPY snitchmd.py /usr/local/bin/snitchmd
RUN chmod +x /usr/local/bin/snitchmd

ENTRYPOINT ["/entrypoint.sh", "snitchmd"]
CMD ["--help"]
