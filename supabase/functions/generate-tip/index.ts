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

    const { game_title, steam_price, epic_price, user_id } = await req.json()

    // Get user search history
    const { data: searches } = await supabaseClient
      .from('user_searches')
      .select('query')
      .eq('user_id', user_id)
      .order('searched_at', { ascending: false })
      .limit(10)

    // Call Gemini AI for quick tip
    const geminiResponse = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${Deno.env.get('GEMINI_API_KEY')}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{
          parts: [{
            text: `Analiza estos precios de juegos y da un tip breve (máx 50 palabras):

Juego: ${game_title}
Precio Steam: ${steam_price ?? 'No disponible'}€
Precio Epic: ${epic_price ?? 'No disponible'}€

Búsquedas recientes del usuario: ${searches?.map((s: any) => s.query).join(', ') || 'Ninguna'}

Enfócate en:
- Mejor oferta entre tiendas
- Valor por dinero
- Momento ideal para comprar

Mantén conciso y práctico.`
          }]
        }]
      })
    })

    const geminiData = await geminiResponse.json()
    const tip = geminiData.candidates[0].content.parts[0].text

    return new Response(JSON.stringify({ tip }), {
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
