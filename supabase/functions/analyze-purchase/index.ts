import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const { game_id, user_id } = await req.json()

    // Get game data from Supabase
    const { data: game, error: gameError } = await supabaseClient
      .from('games')
      .select('*, price_history(*)')
      .eq('id', game_id)
      .single()

    if (gameError) throw gameError

    // Get user search history
    const { data: searches } = await supabaseClient
      .from('user_searches')
      .select('query')
      .eq('user_id', user_id)
      .order('searched_at', { ascending: false })
      .limit(10)

    // Extract current prices
    const steamPrice = game.price_history?.find((p: any) => p.store === 'steam')?.price
    const epicPrice = game.price_history?.find((p: any) => p.store === 'epic')?.price

    // Call Gemini AI for analysis
    const geminiResponse = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${Deno.env.get('GEMINI_API_KEY')}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{
          parts: [{
            text: `Análisis completo de decisión de compra. Responde en JSON:

{
  "recomendacion": "COMPRAR_AHORA" | "ESPERAR" | "EVITAR",
  "confianza": 0-100,
  "resumen": "Resumen de 2-3 frases",
  "factores_clave": ["factor 1", "factor 2", "factor 3"]
}

Juego: ${game.title}
Steam: ${steamPrice ?? 'N/A'}€
Epic: ${epicPrice ?? 'N/A'}€

Búsquedas recientes del usuario: ${searches?.map((s: any) => s.query).join(', ') || 'Ninguna'}`
          }]
        }]
      })
    })

    const geminiData = await geminiResponse.json()
    const analysisText = geminiData.candidates[0].content.parts[0].text

    // Parse JSON response
    const analysis = JSON.parse(analysisText)

    return new Response(JSON.stringify(analysis), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
