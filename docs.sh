swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation --target LangGraph \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path LangGraph \
    --output-path ./docs