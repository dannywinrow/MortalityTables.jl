"""
    get_CMI_table(table_name)

Given the table_name of a `https://www.actuaries.org.uk/learn-and-develop/continuous-mortality-investigation/cmi-mortality-and-morbidity-tables` table, grab it and return it as a `MortalityTable`.

!!! Remember that not all tables have been tested to work.
"""
function get_CMI_table(code)
    series = code[1:2]
    if series == "S3"
        return parseS3()[code]
    end
end

using HTTP
using XLSX
using DataFrames
using Memoize

morturl = Dict(
    "16T" => "https://www.actuaries.org.uk/documents/final-16-series-term-assurance-rates",
    "16P" => "https://www.actuaries.org.uk/documents/final-paip-16-series-mortality-rates-v01-2020-07-10",
    "S3" => "https://www.actuaries.org.uk/documents/final-s3-series-mortality-rates",
    "08T" => "https://www.actuaries.org.uk/documents/final-08-series-assurances-rates",
    "08A" => "https://www.actuaries.org.uk/documents/final-08-series-annuities-mortality-tables",
    "S2" => "https://www.actuaries.org.uk/documents/excel-spreadsheet-containing-s2-mortality-rates"
)

#Tables issued after 1 March 2013 are only available to organisations that subscribe to the CMI

function login()
    include("secret.jl")
    r = HTTP.request("GET","https://www.actuaries.org.uk/user")
    s = String(r.body)
    form_build_id = match(r"name=\"form_build_id\" value=\"([\w-]+)\"",s)[1]

    payload = Dict("name" => user,
                "pass" => pass,
                "form_build_id" => form_build_id,
                "form_id" => "user_login",
                "op" => "Log in")

    rq = HTTP.request("POST","https://www.actuaries.org.uk/user",body=payload)
end

function isloggedin()
    r = HTTP.request("GET","https://www.actuaries.org.uk/user")
    !isnothing(match(r"Log out", String(r.body)))
end

function getserieswb(series)
    fp = "data/$series.xlsx"
    if !isfile(fp)
        !isloggedin() && login()
        r = HTTP.get(morturl[series])
        link = match(r"href=\"(.+\.xls\w?)\"",s)[1]
        HTTP.download(link,fp)
    end
    XLSX.readxlsx(fp)
end

@memoize function parseS3()
    xf = getserieswb("S3")
    mu = XLSX.gettable(xf["mu"];first_row=7) |> DataFrame
    q = XLSX.gettable(xf["q"];first_row=7) |> DataFrame
    key = XLSX.gettable(xf["Key"]) |> DataFrame
    mortalitytables = []
    for name in names(q)[2:end]
        push!(mortalitytables,
            name => MortalityTable(UltimateMortality(Float64.(q[:,name]); start_age = q[1,1])
                ;metadata=TableMetaData(
                provider = "CMI"
                )
            )
        )
    end
    Dict(mortalitytables)
end