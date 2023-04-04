{
    // 默认的过期时间
    local expiry="876600h",
    signing: {
        default: {
            expiry: expiry,
        },
        profiles: {
            server: {
                expiry:  expiry,
                usages: [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            }
        }
    }
}