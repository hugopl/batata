VERSION = {{ (`shards version #{__DIR__}`.strip + "+" + system("git rev-parse --short HEAD || echo unknown").stringify).stringify.strip }}
