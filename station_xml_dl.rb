#!/usr/bin/ruby
# encoding: utf-8
require 'rexml/document'
require 'net/http'

URL = 'http://radiko.jp/v2/station/list/JP13.xml'

begin
  if ARGV.size == 1 then
    indent = Integer(ARGV[0])
  else
    indent = 0
  end

  url = URI.parse(URL)
  req = Net::HTTP::Get.new(url.path)
  res = Net::HTTP.start(url.host, url.port) {|http|
    http.request(req)
  }
  if !res.is_a?(Net::HTTPSuccess) then
    raise ::RuntimeError.new("#{res.class}: #{res.code} #{res.message}")
  end

  doc = REXML::Document.new(res.body) # .new(File.open("JP13.xml"))
  station = []
  doc.elements.each('stations/station') do |element|
    station.push({
      :id   => element.elements['id'].text,
      :name => element.elements['name'].text
    })
  end

  station.each do |st|
    printf("%s%-15s: %s\n", " " * indent, st[:id], st[:name])
  end

  ret = 0
rescue => e
  $stderr.puts("#{e.class}: #{e.message}")
  $stderr.puts(e.backtrace)
  ret = 1
ensure
  exit(ret)
end
