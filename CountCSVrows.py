#########################################
# Count total number of rows in CSV file
#########################################

import csv
import sys

# DECREMENT LOOP FROM:
# http://stackoverflow.com/questions/15063936/csv-error-field-larger-than-field-limit-131072

# Used to increase the field size 

maxInt = sys.maxsize
decrement = True

while decrement:
    # decrease the maxInt value by factor 10 
    # as long as the OverflowError occurs.

    decrement = False
    try:
        csv.field_size_limit(maxInt)
    except OverflowError:
        maxInt = int(maxInt/10)
        decrement = True


# COUNT TOTAL ROWS/ENTRIES IN CSV FILE
# NOTES:
#   1. DictReader automatically skips first row
#   2. Encoding parameter eliminates UNICODEDECODEERROR

with open("donorschoose-org-17feb2012-v1-essays.csv",
          'rt', encoding = 'latin1') as f:
    
    reader = csv.DictReader(f, delimiter=",")

    totalrows=0
    
    for row in reader:
        totalrows+=1

    print ("Total Data Entries:", totalrows)



    
