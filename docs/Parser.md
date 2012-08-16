titi:2 and (toto:'3' or tata:!)
{
   "and": [
      {
         "titi": 2
      },
      {
         "or": [
            {
               "toto": "3"
            },
            {
               "tata": "!"
            }
         ]
      }
   ]
}

titi:2 or tata:3 or toto:4
{
   "or": [
      {
         "titi": 2
      },
      {
         "tata": 3
      },
      {
         "toto": 4
      }
   ]
}

---------------------------------------------------------------------------------------------
Marche !!
http://pegjs.majda.cz/online
http://www.engr.mun.ca/~theo/Misc/exp_parsing.htm#classic

Expression =
  left:AndExpr right:(' '+ 'or' ' '+ AndExpr )*
  {
    if(right.length) {
      var result = {or: [left]}
      for( var i=0; i < right.length; i++) {
        result.or.push(right[i][3]);
      }
      return result;
    } else {
      return left;
    }
  }

AndExpr =
  left:Term right:(' '+ 'and' ' '+ Term )*
  {
    if(right.length) {
      var result = {and: [left]}
      for( var i=0; i < right.length; i++) {
        result.and.push(right[i][3]);
      }
      return result;
    } else {
      return left;
    }
  }

Term =
  Token
/
  '(' ' '* expr:Expression ' '* ')' 
  {return expr;}

Token =
  id:Identifier ' '* ':' ' '* val:Value 
  {
    var obj = {};
    obj[id] = val;
    return obj;
  }

Identifier = 
  first:[a-zA-Z_] next:[a-zA-Z0-9_]* 
  {return first+next.join('');}

Value =
  Boolean / String / Float / Integer / Regex / '!'

Regex = 
  '/' content:('\\/' / [^/])+ '/' flag:('i'/'m')? 
  {return new RegExp(content.join(''), flag);}

Boolean =
  'true' / 'false'

Integer =
  sign:'-'? digit:[0-9]+ 
  {return parseInt(sign+digit.join(''));}

Float =
  digit:Integer '.' decimal:[0-9]+ 
  {return parseFloat(digit+'.'+decimal.join(''));}

String = 
  '"' content:('\\"' / [^"])* '"' 
  {return content.join('');} 
/
  "'" content:("\\'" / [^'])* "'" 
  {return content.join('');}