# doesn't recognize MySQLdb in IDLE

# ********** Use Terminal **********
#
#   >> cd Desktop
#   >> python testMySQLdb.py

import MySQLdb
from collections import Counter

db = MySQLdb.connect("localhost","root","","DonorsChooseFull")

cur = db.cursor()

cur.execute("SELECT * FROM essays where id < 50")

counter = []

for row in cur.fetchall():
    
    essay = row[6].split()

    essay = [word.replace("\\n","").strip(",.!?-").lower() for word in essay]

    # COUNTER CLASS builds dictionary:
    #   key = word
    #   variable = word count

    counter.extend(essay)
    
    most_common = Counter(essay).most_common(5)


freq = Counter(counter)

#for k,v in freq.items():
#    print k,v

print("\n****** Top 50 Words ******")

top = freq.most_common(50)

print '{0:<5} {1:<10} {2:<8}'.format("Rank", "Word", "Word Count")
print '***************************'

count = 1

for i in top:
    print '{0:<5} {1:<10} : {2:<8}'.format(count, i[0],i[1])
    count +=1
