import { useState, useContext, useRef, useEffect } from "react";


const BORP_QUOTE_API = "/api/courierQuote"

export default function Quote() {
  const [quote, setQuote] = useState('Loading Motivation...');

  useEffect(() => {
    fetch(BORP_QUOTE_API)
      .then(response => response.json())
      .then(data => setQuote(data.quote))
      .catch(error => {
        console.error('Error:', error);
        setQuote('Error loading quote');
      });
  }, []);

  
  return (
    <div className="Quantum-Container Title">
      <p>{quote}</p>
    </div>
  );
}