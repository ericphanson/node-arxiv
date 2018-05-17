request = require 'request'
xml2js = require 'xml2js'

makeUrl = (query, max_results = 1000, ids, sort_by='submittedDate') ->
    url = "http://export.arxiv.org/api/query?sortBy=#{sort_by}&max_results=#{max_results}"
    if query
        url += "&search_query=#{query}"
    if ids
        url += "&id_list=#{ids}"
    url

key_map =
    author: 'au'
    q: 'all'
    title: 'ti'
    category: 'cat'

coerceQueryKey = (key) ->
    key_map[key] or key

coerceQueryValue = (key, value) ->
    if key == 'au'
        if matched = value.match /^(\w+).* (\w+)$/
            matched[2] + '_' + matched[1][0]
        else
            value
    else
        value

coerceQuery = (query) ->
    querys = []
    for k, v of query
        k = coerceQueryKey k
        v = coerceQueryValue k, v
        querys.push [k, v].join(':')
    querys.join('+AND+')

coerceIds = (ids = []) ->
    ids.join(',')

unique = (a, k) ->
    a_ = []
    known = {}
    for i in a
        if !known[i[k]]
            known[i[k]] = true
            a_.push i
    return a_

coerceEntry = (entry) -> {
    id: entry.id[0]
    updated: new Date entry.updated[0]
    published: new Date entry.published[0]
    title: entry.title[0].trim().replace(/\s+/g, ' ')
    summary: entry.summary[0].trim().replace(/\s+/g, ' ')
    links: entry.link.map (link) -> {href: link['$']['href'], title: link['$']['title']}
    authors: unique (entry.author.map (author) -> {name: author['name'][0]}), 'name'
    categories: entry.category.map (category) -> category['$']['term']
}

search = (query, cb, max_results, id_list) ->
    console.log makeUrl(coerceQuery(query), max_results, coerceIds(id_list))
    request.get makeUrl(coerceQuery(query), max_results, coerceIds(id_list)), (err, resp, data) ->
        xml2js.parseString data, (err, parsed) ->
            if err?
                cb err
            else
                items = parsed?.feed?.entry?.map coerceEntry
                items ||= []
                total = Number parsed.feed['opensearch:totalResults'][0]['_']
                total ||= 0
                cb err, {items, total}

module.exports = {
    search
}

