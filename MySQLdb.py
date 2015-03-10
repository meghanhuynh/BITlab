# doesn't recognize MySQLdb in IDLE

# ********** Use Terminal **********
#
#   >> cd Desktop
#   >> python testMySQLdb.py
#
#
#   Don't Forget to Turn Server ON!
#
#***********************************


# NEED TO FIX PUNCTUATION ERRORS

import MySQLdb
import re
from collections import Counter

db = MySQLdb.connect("localhost","root","","DonorsChooseFull")

cur = db.cursor()

cur.execute("SELECT * FROM essays where id = 8")

#***********************************
# Build Huge List of Words Found 
#***********************************

def build_wordlist(cur):

    counter = []

    for row in cur.fetchall():

        
        # divide essay field into words

        #essay = row[6].split()

        # '/' will also split fractions
        # can't strip beginning '"'
        
        essay = re.split(r'[\s/,...?!]+', row[6])

        essay = [word.replace("\\n","").strip("'").strip('\n\t ,.:;''""(){}[]!?-').lower() for word in essay]

        # Counter Class builds dictionary:
        #   key = word
        #   variable = word count

        counter.extend(essay)

    freq = Counter(counter)

    return freq

#**************************************
#  Record Top 50 Words Among All Essays
#**************************************

def write_top_words (freq):

    f = open('Top 200 Words','w')

    f.write("\n****** Top 200 Words ******")

    top = freq.most_common(200)


    f.write('\n{0:<5} {1:<15} {2:<8}'.format("Rank", "Word", "Word Count"))
    f.write('\n***************************')

    count = 1

    for i in top:
        f.write('\n{0:<5} {1:<15} : {2:<8}'.format(count, i[0],i[1]))
        count +=1

    print ("Top 200 Words written to file.")
             
    f.close()

#***************************************
#   Record All Words Found in Essays
#***************************************

def write_wordlist (freq):

    t = open("Word List", 'w')

    t.write("\n****** Word Dictionary ******\n")

    t.write("{0:<15} {1:<8}".format("Word", "Count"))
    t.write("\n*****************************")

    for word,word_count in freq.items():
        t.write("\n{0:<15} {1:<8}".format(word, word_count))

    print ("Wordlist written to file.")

    t.close()

#***************************************
#   Count sentences
#***************************************

def count_sentences(cur):
    
    for row in cur.fetchall():
       
        essay = re.split(r'[.\n?!]+', row[6])
        del essay[-1]
        
    essay = [sent.strip() for sent in essay]
        
    count = 0
    flag = 1    # check if the sentence is valid
    for i in essay:

        phrase = i.strip('"').lower()

        words = phrase.split()
        
        # TEST: As Dr / Seuss once said id = 41

        for word in words:
            
            if word in ["mr","mrs","dr","ms","vs"]:
                flag = 0
                
            if word in "bcdefghjklmnopqrstuvwxyz": #REMOVED 'A' and 'I'
                                                   # won't work fo Dr. A or Mrs I
                flag = 0
                    
        if flag == 1:               
            count += 1
            #print i,'\n'   # OUTPUT: interpreted sentences
            
        flag = 1
        

    print "**** There are ", count, " sentences! ****"

    return count

#*************************************
# CALCULATE AVERAGE NUM OF SENTENCES ? 
#*************************************

count_sentences(cur)
