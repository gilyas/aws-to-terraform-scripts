#!/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="$AWS codepipeline list-pipelines" 
else
    cmd[0]="$AWS codepipeline list-pipelines"
fi

pref[0]="pipelines"
tft[0]="aws_codepipeline"
idfilt[0]="name"

#rm -f ${tft[0]}.tf

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm`
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}" | tr -d '"'`
            echo $cname
            fn=`printf "%s__%s.tf" $ttft $cname`
            if [ -f "$fn" ] ; then
                echo "$fn exists already skipping"
                continue
            fi
            printf "resource \"%s\" \"%s\" {" $ttft $cname > $ttft.$cname.tf
            printf "}" $cname >> $ttft.$cname.tf
            printf "terraform import %s.%s %s" $ttft $cname $cname > import_$ttft_$cname.sh
            terraform import $ttft.$cname $cname
            terraform state show $ttft.$cname > t2.txt
            tfa=`printf "%s.%s" $ttft $cname`
            terraform show  -json | jq --arg myt "$tfa" '.values.root_module.resources[] | select(.address==$myt)' > $tfa.json
            #echo $awsj | jq . 
            rm $ttft.$cname.tf
            cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
            #	for k in `cat t1.txt`; do
            #		echo $k
            #	done
            file="t1.txt"
            echo $aws2tfmess > $fn
            rarns=()
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    #echo $tt2
                    if [[ ${tt1} == "arn" ]];then skip=1; fi                
                    if [[ ${tt1} == "id" ]];then skip=1; fi          

                    if [[ ${tt1} == "role_arn" ]];then 
                                skip=0;
                                trole=`echo "$tt2" | rev | cut -d'/' -f 1 | rev | tr -d '"'`
                                rarns+=$trole
                                echo "***trole=$trole"
                                echo "depends_on = [aws_iam_role.$trole]" >> $fn              
                                t1=`printf "%s = aws_iam_role.%s.arn" $tt1 $trole`
                    fi

                    if [[ ${tt1} == "location" ]];then 
                                skip=0;
                                s3buck=`echo "$tt2" | cut -f2- -d'/' | tr -d '"'`
                    fi


                    
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "rule_id" ]];then skip=1;fi
                    #if [[ ${tt1} == "availability_zone" ]];then skip=1;fi
                    if [[ ${tt1} == "availability_zone_id" ]];then skip=1;fi
                    if [[ ${tt1} == "vpc_id" ]]; then
                        tt2=`echo $tt2 | tr -d '"'`
                        t1=`printf "%s = aws_vpc.%s.id" $tt1 $tt2`
                    fi
               
                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo $t1 >> $fn
                fi
                
            done <"$file"

            ## role arn
            for therole in ${rarns[@]}; do
                echo "therole=$therole"
                trole1=`echo $thefole | tr -d '"'`
                echo "calling for $trole1"
                if [ "$trole1" != "" ]; then
                    ../../scripts/050-get-iam-roles.sh $trole1
                fi
            done           
            if [ "$s3buck" != "" ]; then
                ../../scripts/060-get-s3.sh $s3buck
            fi
            
        done
        
    fi
done
terraform fmt
terraform validate
rm -f t*.txt

