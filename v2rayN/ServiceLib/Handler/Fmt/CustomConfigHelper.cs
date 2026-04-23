namespace ServiceLib.Handler.Fmt;

public static class CustomConfigHelper
{
    private static readonly string _tag = nameof(CustomConfigHelper);
    private static readonly HashSet<string> SocksLikeInboundTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "mixed",
        "socks"
    };
    private static readonly HashSet<string> LoopbackReachableListenAddresses = new(StringComparer.OrdinalIgnoreCase)
    {
        "0.0.0.0",
        "::",
        "[::]",
        "::1",
        "[::1]",
        "127.0.0.1",
        "localhost",
        Global.Loopback
    };

    public static int? GetPreSocksPortFromFile(string? fileName)
    {
        if (fileName.IsNullOrEmpty())
        {
            return null;
        }

        try
        {
            var addressFileName = fileName;
            if (!File.Exists(addressFileName))
            {
                addressFileName = Utils.GetConfigPath(addressFileName);
            }
            if (!File.Exists(addressFileName))
            {
                return null;
            }

            return GetPreSocksPort(File.ReadAllText(addressFileName));
        }
        catch (Exception ex)
        {
            Logging.SaveLog(_tag, ex);
            return null;
        }
    }

    public static int? GetPreSocksPort(string? strData)
    {
        if (strData.IsNullOrEmpty())
        {
            return null;
        }

        if (JsonUtils.ParseJson(strData) is not JsonObject config)
        {
            return null;
        }

        return GetV2rayPreSocksPort(config) ?? GetSingboxPreSocksPort(config);
    }

    public static bool IsValidPort(int? port)
    {
        return port is > 0 and <= 65535;
    }

    private static int? GetV2rayPreSocksPort(JsonObject config)
    {
        if (config["inbounds"] is not JsonArray inbounds)
        {
            return null;
        }

        return inbounds
            .Select(GetV2rayInboundSocksPort)
            .FirstOrDefault(IsValidPort);
    }

    private static int? GetSingboxPreSocksPort(JsonObject config)
    {
        if (config["inbounds"] is not JsonArray inbounds)
        {
            return null;
        }

        return inbounds
            .Select(GetSingboxInboundSocksPort)
            .FirstOrDefault(IsValidPort);
    }

    private static int? GetV2rayInboundSocksPort(JsonNode? inboundNode)
    {
        if (inboundNode is not JsonObject inbound)
        {
            return null;
        }

        var protocol = inbound["protocol"]?.ToString();
        if (!IsSocksLike(protocol)
            || !CanConnectViaLoopback(inbound["listen"]?.ToString())
            || !AllowsV2rayNoAuth(inbound))
        {
            return null;
        }

        return TryGetPort(inbound["port"]);
    }

    private static int? GetSingboxInboundSocksPort(JsonNode? inboundNode)
    {
        if (inboundNode is not JsonObject inbound)
        {
            return null;
        }

        var type = inbound["type"]?.ToString();
        if (!IsSocksLike(type)
            || !CanConnectViaLoopback(inbound["listen"]?.ToString())
            || !AllowsSingboxNoAuth(inbound))
        {
            return null;
        }

        return TryGetPort(inbound["listen_port"]);
    }

    private static bool IsSocksLike(string? inboundType)
    {
        return inboundType.IsNotEmpty() && SocksLikeInboundTypes.Contains(inboundType);
    }

    private static bool CanConnectViaLoopback(string? listen)
    {
        return listen.IsNullOrEmpty() || LoopbackReachableListenAddresses.Contains(listen.Trim());
    }

    private static bool AllowsV2rayNoAuth(JsonObject inbound)
    {
        var auth = inbound["settings"]?["auth"]?.ToString();
        return auth.IsNullOrEmpty() || auth.Equals("noauth", StringComparison.OrdinalIgnoreCase);
    }

    private static bool AllowsSingboxNoAuth(JsonObject inbound)
    {
        return inbound["users"] is not JsonArray { Count: > 0 };
    }

    private static int? TryGetPort(JsonNode? portNode)
    {
        if (portNode is null || !int.TryParse(portNode.ToString(), out var port))
        {
            return null;
        }

        return IsValidPort(port) ? port : null;
    }
}
