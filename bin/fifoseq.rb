#!/usr/bin/env ruby

@version = "0.1"

c2s = "#{File.dirname $0}/c2s"
boogie = "Boogie"
cleanup = false

puts "FiFoSeq version #{@version}"

def usage()
    puts "usage: fifoseq.rb <impl>.bpl <K>"
end

def check_file(file,kind,ext)
    if not file \
    or not File.exists? file \
    or not File.extname(file) == ".#{ext}"
    then
        puts "Please give a #{kind} source file -- .#{ext} extension."
        usage()
        exit
    end
end

def bpl_source(file)
    check_file(file,"Boogie source","bpl")
    return file
end

sources, rest = ARGV.partition{|f| File.extname(f) == ".bpl"}
phases, rest = rest.partition{|a| a =~ /\/phaseBound:[0-9]+/}
delays, rest = rest.partition{|a| a =~ /\/delayBound:[0-9]+/}
m2s, rest = rest.partition{|a| a =~ /\/multitosingle/}

if sources.empty? then
	puts "Please specify at least one Boogie source file (.bpl)."
	exit -1
end

if phases.empty? then
	puts "Please specify the number of phases with /phaseBound:_."
	exit -1
end

if delays.empty? then
  delays = ["/delayBound:0"]
  # puts "Please specify a delay bound with /delayBound:_."
  # exit -1
end

m2s = !m2s.empty?

phases = phases.first.sub(/\/phaseBound:([0-9]+)/, '\1')
delays = delays.first.sub(/\/delayBound:([0-9]+)/, '\1')
rest = rest * " "

name = File.basename(sources.last,".bpl")

comp = "#{name}.comp.bpl"

`cat #{sources * " "} > #{comp}`

seq = "#{name}.FiFoSeq.#{phases}-phase.bpl"

puts " #{"-"*78} "

puts "Sequentializing #{name} with #{phases}-phase translation."
puts "-- Phases: #{phases}"
puts "-- Delays: #{delays}"

cmd = [
  c2s, comp,
  "--seq-framework",
  m2s ? "--multi-to-single" : "",
  "--phase-bounding #{phases} #{delays}",
  "--prepare-for-back-end",
  "--print #{seq}"
]

t0 = Time.now
output = `#{cmd * " "}`
if not $?.success? then
  puts "Sequentialization failed:"
  puts "#{cmd * " "}"
  puts output
  exit
else
  # puts output
  puts "Finished in #{Time.now - t0}s"
end

puts " #{"-" * 78} "

puts "Verifying #{seq} with Boogie..."
puts "-- StratifiedInline"
puts "-- ExtractLoops"
puts "-- and: #{rest.empty? ? "--" : rest }"

cmd = [ 
  boogie, seq, 
  "/stratifiedInline:1", "/extractLoops", 
  rest, 
  "/errorLimit:1", "/errorTrace:2"
]

# other interesting flags: 
# /errorLimit:1 -- only one error (per procedure)
# /errorTrace:2 -- include all trace labels in error output

t0 = Time.now
output = `#{cmd * " "}`
if not $?.success? then
  puts "Verification failed:"
  puts "#{cmd * " "}"
  puts output
  exit
else
  puts output
  puts "Finished in #{Time.now - t0}s."
end 

puts " #{"-" * 78} "

# if cleanup then
#     File.delete( "#{src}.async.bpl" )
# end